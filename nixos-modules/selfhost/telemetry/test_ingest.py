import base64
import importlib.util
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import Mock, patch


SOURCE = Path(__file__).with_name("ingest.py")


class DatabaseError(Exception):
    sqlstate = "XX000"


class DataError(DatabaseError):
    pass


class IntegrityError(DatabaseError):
    pass


class Cursor:
    def __init__(self, database):
        self.database = database

    def __enter__(self):
        return self

    def __exit__(self, *_):
        pass

    def execute(self, statement, params):
        self.database.statements.append((statement, params))
        if self.database.failure:
            error, self.database.failure = self.database.failure, None
            raise error


class Database:
    closed = False

    def __init__(self, failure=None):
        self.failure = failure
        self.statements = []
        self.commit = Mock()
        self.rollback = Mock()
        self.close = Mock()

    def cursor(self):
        return Cursor(self)


class IngesterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        psycopg = types.ModuleType("psycopg")
        psycopg.Error, psycopg.DataError, psycopg.IntegrityError = DatabaseError, DataError, IntegrityError
        psycopg.connect = Mock()
        psycopg_types = types.ModuleType("psycopg.types")
        psycopg_json = types.ModuleType("psycopg.types.json")
        psycopg_json.Jsonb = lambda value: value
        mqtt = types.ModuleType("paho.mqtt.client")
        mqtt.MQTT_ERR_SUCCESS = 0
        mqtt.Client = Mock()
        mqtt.CallbackAPIVersion = types.SimpleNamespace(VERSION2=2)
        mqtt.MQTTv311 = 4
        with patch.dict(sys.modules, {"psycopg": psycopg, "psycopg.types": psycopg_types,
                                      "psycopg.types.json": psycopg_json, "paho": types.ModuleType("paho"),
                                      "paho.mqtt": types.ModuleType("paho.mqtt"), "paho.mqtt.client": mqtt}):
            spec = importlib.util.spec_from_file_location("ingest_test", SOURCE)
            cls.ingest = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.ingest)
        cls.ingest.mqtt = mqtt

    def setUp(self):
        self.ingest.db = None
        self.client = Mock()
        self.client.ack.return_value = 0
        self.client.publish.return_value.rc = 0
        self.message = types.SimpleNamespace(topic="apartment/room/air-quality", qos=1, mid=5,
                                             retain=False, payload=b'{"time_valid":true,"measured_at_epoch":1700000000}')

    def test_commit_precedes_ack_and_preserves_measurement_time(self):
        db = Database()
        order = []
        db.commit.side_effect = lambda: order.append("commit")
        self.client.ack.side_effect = lambda *args: (order.append("ack"), 0)[1]
        with patch.object(self.ingest, "connect_db", return_value=db):
            self.ingest.on_message(self.client, None, self.message)
        self.assertEqual(order, ["commit", "ack"])
        self.assertEqual(db.statements[0][1][-2].timestamp(), 1700000000)

    def test_transient_failure_exits_without_ack(self):
        db = Database(DatabaseError("connection lost"))
        with patch.object(self.ingest, "connect_db", return_value=db):
            with self.assertRaises(DatabaseError):
                self.ingest.on_message(self.client, None, self.message)
        self.client.ack.assert_not_called()
        db.close.assert_called_once()

    def test_bad_message_commits_dead_letter_before_ack(self):
        db = Database(DataError("invalid payload"))
        with patch.object(self.ingest, "connect_db", return_value=db):
            self.ingest.on_message(self.client, None, self.message)
        self.assertEqual(len(db.statements), 2)
        self.assertIn("mqtt_dead_letters", db.statements[1][0])
        db.rollback.assert_called_once()
        db.commit.assert_called_once()
        self.client.ack.assert_called_once_with(5, 1)

    def test_forwarded_message_acks_database_commit_and_deduplicates_by_id(self):
        identifier = "25e22fd0-2e46-429f-a13b-31d83b7257f0"
        data = {"id": identifier, "topic": "apartment/room/air-quality",
                "payload": base64.b64encode(self.message.payload).decode(), "qos": 1, "retained": False}
        self.message.topic = "telemetry/forward"
        self.message.payload = json.dumps(data).encode()
        db = Database()
        events = []
        db.commit.side_effect = lambda: events.append("commit")
        self.client.publish.side_effect = lambda *args, **kwargs: (events.append("publish"), types.SimpleNamespace(rc=0))[1]
        self.client.ack.side_effect = lambda *args: (events.append("ack"), 0)[1]
        with patch.object(self.ingest, "connect_db", return_value=db):
            self.ingest.on_message(self.client, None, self.message)
        self.assertEqual(events, ["commit", "publish", "ack"])
        self.assertIn("ON CONFLICT (ingress_id) DO NOTHING", db.statements[0][0])
        self.assertEqual(db.statements[0][1][-1], identifier)
        self.client.publish.assert_called_once_with("telemetry/ack/" + identifier, qos=1)

    def test_persistent_manual_ack_session(self):
        with patch.object(self.ingest, "open", create=True) as password, patch.object(self.ingest.os, "environ", {"MQTT_PASSWORD_FILE": "/fake"}):
            password.return_value.__enter__.return_value.read.return_value = "secret"
            self.ingest.main()
        self.assertFalse(self.ingest.mqtt.Client.call_args.kwargs["clean_session"])
        self.assertTrue(self.ingest.mqtt.Client.call_args.kwargs["manual_ack"])


if __name__ == "__main__":
    unittest.main()
