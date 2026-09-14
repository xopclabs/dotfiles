import json
import os
import time

import paho.mqtt.client as mqtt
import psycopg
from psycopg.types.json import Jsonb


def connect_db():
    return psycopg.connect("host=/run/postgresql dbname=telemetry user=telemetry")


db = None


def on_connect(client, userdata, flags, reason_code, properties=None):
    client.subscribe("home/apartment/#", qos=1)
    client.subscribe("homeassistant/#", qos=1)


def on_message(client, userdata, message):
    global db

    try:
        value = json.loads(message.payload.decode("utf-8"))
        payload = Jsonb(value)
        payload_text = None
    except (UnicodeDecodeError, json.JSONDecodeError):
        payload = None
        payload_text = message.payload.decode("utf-8", errors="replace")

    while True:
        try:
            if db is None or db.closed:
                db = connect_db()
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO mqtt_messages (topic, payload, payload_text, qos, retained) VALUES (%s, %s, %s, %s, %s)",
                    (message.topic, payload, payload_text, message.qos, message.retain),
                )
            db.commit()
            return
        except psycopg.Error:
            if db is not None:
                db.close()
            db = None
            time.sleep(2)


password = open(os.environ["MQTT_PASSWORD_FILE"], encoding="utf-8").read().strip()
client = mqtt.Client(
    mqtt.CallbackAPIVersion.VERSION2,
    client_id="telemetry-ingester",
    protocol=mqtt.MQTTv311,
)
client.username_pw_set("telemetry-ingester", password)
client.on_connect = on_connect
client.on_message = on_message
client.reconnect_delay_set(min_delay=1, max_delay=30)
client.connect(os.environ.get("MQTT_HOST", "10.250.250.1"), 1883, 60)
client.loop_forever()
