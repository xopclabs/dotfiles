import base64
import binascii
import json
import logging
import os
from datetime import datetime, timezone
from uuid import UUID

import paho.mqtt.client as mqtt
import psycopg
from psycopg.types.json import Jsonb


def connect_db():
    return psycopg.connect("host=/run/postgresql dbname=telemetry user=telemetry")


log = logging.getLogger(__name__)
db = None


def measurement_time(topic, value):
    if topic != "apartment/room/air-quality" or not isinstance(value, dict):
        return None
    epoch = value.get("measured_at_epoch")
    if value.get("time_valid") is not True or type(epoch) not in (int, float):
        return None
    try:
        return datetime.fromtimestamp(epoch, timezone.utc)
    except (ValueError, OverflowError, OSError):
        return None


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code != 0:
        raise RuntimeError(f"MQTT connection rejected: {reason_code}")
    log.info("MQTT connected (existing session: %s)", flags.session_present)
    for topic in ("apartment/#", "homeassistant/#", "telemetry/forward"):
        result, _ = client.subscribe(topic, qos=1)
        if result != mqtt.MQTT_ERR_SUCCESS:
            raise RuntimeError(f"MQTT subscribe failed for {topic}: {result}")


def unwrap(message):
    if message.topic != "telemetry/forward":
        return None, message.topic, message.payload, message.qos, message.retain
    envelope = json.loads(message.payload)
    identifier = str(UUID(envelope["id"]))
    topic = envelope["topic"]
    if not isinstance(topic, str) or not topic.startswith(("apartment/", "homeassistant/", "home/apartment/")):
        raise ValueError("Forwarded MQTT topic is not allowed")
    payload = base64.b64decode(envelope["payload"], validate=True)
    qos = envelope["qos"]
    retained = envelope["retained"]
    if qos not in (0, 1, 2) or not isinstance(retained, bool):
        raise ValueError("Invalid forwarded MQTT flags")
    return identifier, topic, payload, qos, retained


def on_message(client, userdata, message):
    global db
    try:
        identifier, topic, raw, qos, retained = unwrap(message)
    except (ValueError, KeyError, TypeError, UnicodeDecodeError, binascii.Error):
        log.exception("Invalid telemetry envelope; keeping it in MQTT for investigation")
        raise
    try:
        value = json.loads(raw.decode("utf-8"))
        payload = Jsonb(value)
        payload_text = None
    except (UnicodeDecodeError, json.JSONDecodeError):
        value = None
        payload = None
        payload_text = raw.decode("utf-8", errors="replace")

    try:
        if db is None or db.closed:
            db = connect_db()
        try:
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO mqtt_messages (topic, payload, payload_text, qos, retained, measured_at, ingress_id) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s) ON CONFLICT (ingress_id) DO NOTHING",
                    (topic, payload, payload_text, qos, retained, measurement_time(topic, value), identifier),
                )
        except (psycopg.DataError, psycopg.IntegrityError) as error:
            log.error("Invalid MQTT message on %s (SQLSTATE %s); storing in dead letters",
                      topic, error.sqlstate)
            db.rollback()
            with db.cursor() as dead:
                dead.execute("INSERT INTO mqtt_dead_letters (topic, payload, error, ingress_id) "
                             "VALUES (%s, %s, %s, %s) ON CONFLICT (ingress_id) DO NOTHING",
                             (topic, raw, str(error)[:1000], identifier))
        db.commit()
        if identifier is not None:
            result = client.publish(f"telemetry/ack/{identifier}", qos=1)
            if result.rc != mqtt.MQTT_ERR_SUCCESS:
                raise RuntimeError(f"Application acknowledgement failed: {result.rc}")
        result = client.ack(message.mid, message.qos)
        if result != mqtt.MQTT_ERR_SUCCESS:
            raise RuntimeError(f"MQTT acknowledgement failed: {result}")
    except psycopg.Error:
        log.exception("Database write failed for MQTT topic %s; restarting without acknowledging", topic)
        if db is not None:
            db.close()
            db = None
        raise


def main():
    logging.basicConfig(level=logging.INFO)
    with open(os.environ["MQTT_PASSWORD_FILE"], encoding="utf-8") as password_file:
        password = password_file.read().strip()
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id="telemetry-ingester",
        clean_session=False,
        protocol=mqtt.MQTTv311,
        manual_ack=True,
    )
    client.username_pw_set("telemetry-ingester", password)
    client.on_connect = on_connect
    client.on_message = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=30)
    client.connect(os.environ.get("MQTT_HOST", "10.250.250.1"), 1883, 60)
    client.loop_forever()


if __name__ == "__main__":
    main()
