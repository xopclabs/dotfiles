"""Run with PostgreSQL tools on PATH; uses a disposable local database."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class CO2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="grafana-co2-")
        cls.root = Path(cls.temp.name)
        cls.env = dict(os.environ, PGHOST=str(cls.root), PGDATABASE="postgres")
        subprocess.run(["initdb", "-D", str(cls.root / "db"), "-A", "trust"],
                       check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["pg_ctl", "-D", str(cls.root / "db"), "-l", str(cls.root / "log"),
                        "-o", f"-k {cls.root} -c listen_addresses=''", "-w", "start"],
                       check=True, stdout=subprocess.DEVNULL)
        cls.sql("CREATE TABLE mqtt_messages (id bigint GENERATED ALWAYS AS IDENTITY, "
                "received_at timestamptz, topic text, payload jsonb, retained boolean)")

    @classmethod
    def tearDownClass(cls):
        subprocess.run(["pg_ctl", "-D", str(cls.root / "db"), "-m", "immediate", "stop"],
                       check=True, stdout=subprocess.DEVNULL)
        cls.temp.cleanup()

    @classmethod
    def sql(cls, query):
        return subprocess.check_output(["psql", "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", query],
                                       env=cls.env, text=True).strip()

    def check_episode(self, readings, state, minutes=None):
        self.sql("TRUNCATE mqtt_messages")
        for reading in readings:
            age, ppm, *retained = reading
            payload = json.dumps({"co2_ppm": ppm})
            self.sql("INSERT INTO mqtt_messages (received_at, topic, payload, retained) "
                     f"VALUES (now() - interval '{age} minutes', 'apartment/room/air-quality', "
                     f"'{payload}', {'true' if retained and retained[0] else 'false'})")
        actual_state, actual_minutes = map(float, self.sql(
            Path(__file__).with_name("co2.sql").read_text()).split("|"))
        self.assertEqual(actual_state, state)
        if minutes is not None:
            self.assertAlmostEqual(actual_minutes, minutes, delta=0.1)

    def test_qualification(self):
        self.check_episode([(20, 1200)], 0)
        self.check_episode([(9, 1200), (0, 1250)], 0)
        self.check_episode([(10, 1000), (0, 1250)], 1, 10)

    def test_hysteresis(self):
        self.check_episode([(20, 1200), (10, 1250), (0, 900)], 1, 20)
        self.check_episode([(20, 1200), (10, 1250), (0, 800)], 1, 20)
        self.check_episode([(20, 1200), (10, 1250), (0, 799)], 0)

    def test_run_breaks(self):
        self.check_episode([(15, 1200), (8, 950), (0, 1250)], 0)
        self.check_episode([(31, 1200), (0, 1250)], 0)

    def test_reset_requires_new_qualification(self):
        self.check_episode([(40, 1200), (30, 1250), (20, 700), (8, 1200), (0, 1250)], 0)

    def test_retained_does_not_qualify_or_resolve(self):
        self.check_episode([(10, 1200, True), (0, 1250)], 0)
        self.check_episode([(20, 1200), (10, 1250), (0, 700, True)], 1, 20)

    def test_latched_duration_survives_another_high_run(self):
        self.check_episode([(40, 1200), (30, 1250), (20, 900), (10, 1200), (0, 1250)], 1, 40)


if __name__ == "__main__":
    unittest.main()
