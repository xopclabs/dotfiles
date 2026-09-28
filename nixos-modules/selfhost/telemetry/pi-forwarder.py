#!/usr/bin/env python3
"""Durably spool local MQTT deliveries until homelab confirms PostgreSQL commit."""
import base64
import json
import logging
import os
import sqlite3
import threading
import time
import uuid

import paho.mqtt.client as mqtt

LOG = logging.getLogger("telemetry-forwarder")
TOPICS = ("apartment/#", "homeassistant/#", "home/apartment/#")
DB_PATH = os.environ.get("FORWARDER_DB", "/var/lib/telemetry-forwarder/queue.sqlite")


def spool(path):
    db = sqlite3.connect(path, check_same_thread=False, timeout=30)
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA synchronous=FULL")
    db.execute("""CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY, sequence INTEGER NOT NULL UNIQUE,
        topic TEXT NOT NULL, payload BLOB NOT NULL, qos INTEGER NOT NULL, retained INTEGER NOT NULL
    )""")
    db.execute("CREATE TABLE IF NOT EXISTS counter (value INTEGER NOT NULL)")
    db.execute("INSERT INTO counter SELECT 0 WHERE NOT EXISTS (SELECT 1 FROM counter)")
    db.commit()
    return db


class Forwarder:
    def __init__(self, database, local_password, remote_password):
        self.db = database
        self.lock = threading.Lock()
        self.pending = {}
        self.connected = threading.Event()
        self.local = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                                 client_id="apartment-pi-spool", clean_session=False,
                                 protocol=mqtt.MQTTv311, manual_ack=True)
        self.local.username_pw_set("telemetry-forwarder", local_password)
        self.local.on_connect = self.on_local_connect
        self.local.on_message = self.on_local_message
        self.remote = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                                  client_id="apartment-pi-ledger", clean_session=False,
                                  protocol=mqtt.MQTTv311)
        self.remote.username_pw_set("apartment-bridge", remote_password)
        self.remote.on_connect = self.on_remote_connect
        self.remote.on_disconnect = self.on_remote_disconnect
        self.remote.on_message = self.on_remote_message
        self.remote.reconnect_delay_set(min_delay=1, max_delay=30)

    def on_local_connect(self, client, userdata, flags, reason, properties=None):
        if reason != 0:
            LOG.error("Local MQTT refused connection: %s", reason)
            return
        LOG.info("Local MQTT connected; existing session: %s", flags.session_present)
        for topic in TOPICS:
            result, _ = client.subscribe(topic, qos=1)
            if result != mqtt.MQTT_ERR_SUCCESS:
                raise RuntimeError(f"Local subscription failed: {result}")

    def on_local_message(self, client, userdata, message):
        identifier = str(uuid.uuid4())
        try:
            with self.lock:
                self.db.execute("UPDATE counter SET value = value + 1")
                self.db.execute("INSERT INTO messages SELECT ?, value, ?, ?, ?, ? FROM counter",
                                (identifier, message.topic, message.payload, message.qos, int(message.retain)))
                self.db.commit()
            # Local broker may forget the delivery now; the copy is fsynced in SQLite.
            result = client.ack(message.mid, message.qos)
            if result != mqtt.MQTT_ERR_SUCCESS:
                raise RuntimeError(f"Local MQTT acknowledgement failed: {result}")
        except Exception:
            LOG.exception("Spooling failed; stopping before acknowledging the MQTT delivery")
            os._exit(1)

    def on_remote_connect(self, client, userdata, flags, reason, properties=None):
        if reason != 0:
            LOG.error("Homelab MQTT refused connection: %s", reason)
            return
        result, _ = client.subscribe("telemetry/ack/#", qos=1)
        if result != mqtt.MQTT_ERR_SUCCESS:
            raise RuntimeError(f"Acknowledgement subscription failed: {result}")
        self.connected.set()
        LOG.info("Homelab MQTT connected; existing session: %s", flags.session_present)

    def on_remote_disconnect(self, client, userdata, disconnect_flags, reason, properties=None):
        self.connected.clear()
        LOG.warning("Homelab MQTT disconnected: %s", reason)

    def on_remote_message(self, client, userdata, message):
        identifier = message.topic.removeprefix("telemetry/ack/")
        try:
            identifier = str(uuid.UUID(identifier))
        except ValueError:
            return
        try:
            with self.lock:
                self.db.execute("DELETE FROM messages WHERE id = ?", (identifier,))
                self.db.commit()
                self.pending.pop(identifier, None)
        except Exception:
            LOG.exception("Failed to remove committed message from spool")
            os._exit(1)

    def send_pending(self):
        if not self.connected.is_set():
            return
        now = time.monotonic()
        with self.lock:
            rows = self.db.execute("SELECT id, topic, payload, qos, retained FROM messages ORDER BY sequence LIMIT 100").fetchall()
            for identifier, topic, payload, qos, retained in rows:
                if now - self.pending.get(identifier, -100) < 10:
                    continue
                data = json.dumps({"id": identifier, "topic": topic,
                                   "payload": base64.b64encode(payload).decode("ascii"),
                                   "qos": qos, "retained": bool(retained)}, separators=(",", ":"))
                result = self.remote.publish("telemetry/forward", data, qos=1)
                if result.rc != mqtt.MQTT_ERR_SUCCESS:
                    self.connected.clear()
                    break
                self.pending[identifier] = now
            if rows:
                LOG.info("Spool oldest batch: %d messages; sent/retried as needed", len(rows))

    def run(self):
        self.local.connect("127.0.0.1", 1883, 60)
        self.remote.connect_async("10.250.250.1", 1883, 60)
        self.local.loop_start()
        self.remote.loop_start()
        while True:
            self.send_pending()
            time.sleep(2)


def main():
    logging.basicConfig(level=logging.INFO)
    with open(os.environ["FORWARDER_LOCAL_PASSWORD_FILE"], encoding="utf-8") as secret:
        local_password = secret.read().strip()
    with open(os.environ["FORWARDER_REMOTE_PASSWORD_FILE"], encoding="utf-8") as secret:
        remote_password = secret.read().strip()
    Forwarder(spool(DB_PATH), local_password, remote_password).run()


if __name__ == "__main__":
    main()
