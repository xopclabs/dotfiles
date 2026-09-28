import importlib.util
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch


class ForwarderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        mqtt = types.ModuleType("paho.mqtt.client")
        mqtt.MQTT_ERR_SUCCESS = 0
        mqtt.CallbackAPIVersion = types.SimpleNamespace(VERSION2=2)
        mqtt.MQTTv311 = 4
        mqtt.Client = Mock(side_effect=lambda *args, **kwargs: Mock())
        with patch.dict(sys.modules, {"paho": types.ModuleType("paho"),
                                      "paho.mqtt": types.ModuleType("paho.mqtt"),
                                      "paho.mqtt.client": mqtt}):
            spec = importlib.util.spec_from_file_location("pi_forwarder_test", Path(__file__).with_name("pi-forwarder.py"))
            cls.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.module)
        cls.module.mqtt = mqtt

    def test_local_commit_precedes_ack_and_remote_ack_deletes_durably(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "queue.sqlite")
            forwarder = self.module.Forwarder(self.module.spool(path), "local", "remote")
            message = types.SimpleNamespace(topic="apartment/room/air-quality", payload=b"sample", qos=1,
                                            retain=False, mid=4)
            counts = []
            forwarder.local.ack.side_effect = lambda *args: (counts.append(forwarder.db.execute("SELECT count(*) FROM messages").fetchone()[0]), 0)[1]
            forwarder.on_local_message(forwarder.local, None, message)
            self.assertEqual(counts, [1])
            identifier = forwarder.db.execute("SELECT id FROM messages").fetchone()[0]
            forwarder.connected.set()
            forwarder.remote.publish.return_value.rc = 0
            forwarder.send_pending()
            self.assertEqual(forwarder.db.execute("SELECT count(*) FROM messages").fetchone()[0], 1)
            forwarder.on_remote_message(forwarder.remote, None,
                                        types.SimpleNamespace(topic="telemetry/ack/" + identifier))
            self.assertEqual(forwarder.db.execute("SELECT count(*) FROM messages").fetchone()[0], 0)
            forwarder.db.close()
            self.assertEqual(self.module.spool(path).execute("SELECT count(*) FROM messages").fetchone()[0], 0)

    def test_unacknowledged_messages_survive_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "queue.sqlite")
            first = self.module.Forwarder(self.module.spool(path), "local", "remote")
            first.local.ack.return_value = 0
            first.on_local_message(first.local, None,
                                   types.SimpleNamespace(topic="apartment/test", payload=b"a", qos=1,
                                                         retain=False, mid=1))
            first.db.close()
            second = self.module.Forwarder(self.module.spool(path), "local", "remote")
            second.connected.set()
            second.remote.publish.return_value.rc = 0
            second.send_pending()
            self.assertEqual(second.remote.publish.call_count, 1)
            self.assertEqual(second.db.execute("SELECT count(*) FROM messages").fetchone()[0], 1)
            second.db.close()


if __name__ == "__main__":
    unittest.main()
