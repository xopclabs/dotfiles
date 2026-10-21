import asyncio
import tempfile
import time
import unittest
from collections import deque

from PIL import Image

from catprinter.render import Options
from catprinter.service import History, Rejected, Service


class Transport:
    def __init__(self):
        self.connected = True
        self.flags = 0
        self.last_reply = time.monotonic()
        self.started = asyncio.Queue()
        self.release = asyncio.Queue()
        self.printed = []
        self.outcomes = deque()
        self.concurrent = 0
        self.peak = 0

    async def connect(self):
        self.connected = True

    async def close(self):
        self.connected = False

    async def status(self):
        self.last_reply = time.monotonic()
        return self.flags

    async def print_job(self, image, started):
        self.concurrent += 1
        self.peak = max(self.peak, self.concurrent)
        self.flags = 0x80
        started()
        self.printed.append(image.height)
        await self.started.put(image.height)
        try:
            await self.release.get()
            outcome = self.outcomes.popleft() if self.outcomes else "finished"
            self.flags = 0x80 if outcome == "sent" else 0
            return outcome
        finally:
            self.concurrent -= 1


class QueueTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.transport = Transport()
        self.history = History(self.directory.name + "/jobs.sqlite")
        self.service = Service(self.transport, self.history)
        self.service.health = "ready"

    async def asyncTearDown(self):
        await self.service.stop()
        self.directory.cleanup()

    def submit(self, height=1, key=None):
        return self.service.submit(Image.new("1", (384, height), 0), Options(), key=key)

    async def next_print(self):
        return await asyncio.wait_for(self.transport.started.get(), 1)

    async def test_accept_while_printing_and_drain_in_fifo_order(self):
        first = self.submit(1)
        await self.service.start()
        self.assertEqual(await self.next_print(), 1)
        self.assertFalse(self.service.available)
        self.assertTrue(self.service.status()["accepting_jobs"])
        self.assertEqual(self.service.status()["state"], "printing")
        second, third = self.submit(2), self.submit(3)
        self.assertEqual((second["state"], third["state"]), ("queued", "queued"))
        self.assertEqual(self.service.status()["queued"], 2)
        await self.transport.release.put(None)
        self.assertEqual(await self.next_print(), 2)
        await self.transport.release.put(None)
        self.assertEqual(await self.next_print(), 3)
        self.assertEqual(self.history.get(first["id"])["state"], "finished")
        self.assertEqual(self.transport.printed, [1, 2, 3])
        self.assertEqual(self.transport.peak, 1)

    async def test_busy_probe_preserves_waiting_job(self):
        self.transport.flags = 0x80
        self.service.health = "busy"
        job = self.submit()
        await self.service.probe()
        self.assertEqual(self.history.get(job["id"])["state"], "queued")
        await self.service.start()
        await asyncio.sleep(0.02)
        self.assertEqual(self.transport.printed, [])
        self.transport.flags = 0
        self.service.changed.set()
        self.assertEqual(await self.next_print(), 1)

    async def test_unconfirmed_completion_waits_without_dropping_or_retrying(self):
        self.transport.outcomes.append("sent")
        first = self.submit(1)
        second = self.submit(2)
        await self.service.start()
        self.assertEqual(await self.next_print(), 1)
        await self.transport.release.put(None)
        await asyncio.sleep(0.02)
        self.assertEqual(self.history.get(first["id"])["state"], "sent")
        self.assertEqual(self.history.get(second["id"])["state"], "queued")
        self.assertEqual(self.transport.printed, [1])
        self.transport.flags = 0
        self.service.changed.set()
        self.assertEqual(await self.next_print(), 2)
        self.assertEqual(self.transport.printed, [1, 2])

    async def test_queue_cap_and_idempotency_still_apply_while_busy(self):
        self.transport.flags = 0x80
        self.service.health = "busy"
        original = self.submit(key="same")
        for _ in range(self.service.queue_size - 1):
            self.submit()
        self.assertFalse(self.service.status()["accepting_jobs"])
        with self.assertRaises(Rejected) as error:
            self.submit()
        self.assertEqual(error.exception.status, 429)
        self.assertEqual(self.submit(key="same")["id"], original["id"])

    async def test_admission_survives_active_job_reconnect(self):
        self.service.active = "reconnecting-job"
        self.transport.connected = False
        self.transport.last_reply = 0
        try:
            self.assertEqual(self.submit()["state"], "queued")
        finally:
            self.service.active = None

    async def test_admission_survives_between_job_reconnect(self):
        self.transport.connected = False
        self.assertEqual(self.submit()["state"], "queued")
        self.transport.last_reply = 0
        with self.assertRaises(Rejected):
            self.submit()

    async def test_offline_fault_and_maintenance_still_reject(self):
        for state in ("unavailable", "fault", "starting"):
            self.service.health = state
            with self.assertRaises(Rejected):
                self.submit()
        self.service.health = "ready"
        self.transport.flags = 0x01
        with self.assertRaises(Rejected):
            self.submit()
        self.transport.flags = 0
        self.service.maintenance = True
        with self.assertRaises(Rejected):
            self.submit()

    async def test_busy_jobs_still_expire(self):
        self.service.expiry = 0.001
        self.transport.flags = 0x80
        self.service.health = "busy"
        job = self.submit()
        await asyncio.sleep(0.01)
        await self.service.start()
        await asyncio.sleep(0.02)
        self.assertEqual(self.history.get(job["id"])["state"], "expired")
        self.assertEqual(self.transport.printed, [])


if __name__ == "__main__":
    unittest.main()
