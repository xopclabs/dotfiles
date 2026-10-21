import asyncio
import contextlib
import json
import logging
import sqlite3
import time
import uuid
from collections import deque
from dataclasses import asdict
from pathlib import Path

LOG = logging.getLogger(__name__)
TERMINAL = ("finished", "sent", "uncertain", "failed", "cancelled", "expired")


class Rejected(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


class History:
    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("""CREATE TABLE IF NOT EXISTS jobs (
            id TEXT PRIMARY KEY, state TEXT NOT NULL, created REAL NOT NULL,
            updated REAL NOT NULL, rows INTEGER NOT NULL, client TEXT NOT NULL,
            options TEXT NOT NULL, reason TEXT, request_key TEXT UNIQUE)""")
        self.db.execute(
            "UPDATE jobs SET state='uncertain', reason='service_restart', updated=? WHERE state='printing'",
            (time.time(),),
        )
        self.db.execute(
            "UPDATE jobs SET state='cancelled', reason='service_restart', updated=? WHERE state IN ('queued','preparing')",
            (time.time(),),
        )
        self.db.commit()
        self.prune()

    def prune(self):
        cutoff = time.time() - 7 * 86400
        self.db.execute(
            "DELETE FROM jobs WHERE updated < ? AND state NOT IN ('queued','preparing','printing')",
            (cutoff,),
        )
        self.db.commit()

    def add(self, job_id, rows, client, options, key=None):
        now = time.time()
        self.db.execute(
            "INSERT INTO jobs VALUES (?,?,?,?,?,?,?,?,?)",
            (
                job_id,
                "queued",
                now,
                now,
                rows,
                client,
                json.dumps(asdict(options)),
                None,
                key,
            ),
        )
        self.db.commit()

    def set(self, job_id, state, reason=None):
        self.db.execute(
            "UPDATE jobs SET state=?,reason=?,updated=? WHERE id=?",
            (state, reason, time.time(), job_id),
        )
        self.db.commit()
        LOG.info("job=%s state=%s reason=%s", job_id, state, reason)

    @staticmethod
    def decode(row):
        if row is None:
            return None
        value = dict(row)
        value["options"] = json.loads(value["options"])
        value.pop("request_key", None)
        return value

    def get(self, job_id):
        return self.decode(
            self.db.execute("SELECT * FROM jobs WHERE id=?", (job_id,)).fetchone()
        )

    def by_key(self, key):
        return (
            self.decode(
                self.db.execute(
                    "SELECT * FROM jobs WHERE request_key=?", (key,)
                ).fetchone()
            )
            if key
            else None
        )

    def list(self, client=None):
        self.prune()
        query = "SELECT * FROM jobs"
        parameters = ()
        if client is not None:
            query += " WHERE client=?"
            parameters = (client,)
        return [
            self.decode(row)
            for row in self.db.execute(
                query + " ORDER BY created DESC LIMIT 100", parameters
            )
        ]


class Service:
    def __init__(self, transport, history, interval=30, queue_size=5, expiry=1800):
        self.transport, self.history = transport, history
        self.interval, self.queue_size, self.expiry = interval, queue_size, expiry
        self.pending = deque()
        self.images = {}
        self.active = None
        self.maintenance = False
        self.released = asyncio.Event()
        self.changed = asyncio.Event()
        self.task = None
        self.health = "starting"
        self.last_error = None
        self.last_prune = time.monotonic()

    @property
    def available(self):
        """Ready to start a physical print, not merely to accept a queued job."""
        t = self.transport
        recent = time.monotonic() - t.last_reply <= self.interval + 10
        return (
            not self.maintenance
            and t.connected
            and self.health == "ready"
            and self.active is None
            and recent
            and t.flags is not None
            and not t.flags & 0x8F
        )

    @property
    def accepting_jobs(self):
        """Accept during printing/reconnects; faults or failed probes close admission."""
        t = self.transport
        recent = time.monotonic() - t.last_reply <= self.interval + 10
        return (
            not self.maintenance
            and self.health in ("ready", "busy")
            and not (t.flags is not None and t.flags & 0x0F)
            and (self.active is not None or (recent and t.flags is not None))
        )

    def check_submission(self):
        if not self.accepting_jobs:
            raise Rejected(503, "Printer unavailable; no job was queued")
        if len(self.pending) >= self.queue_size:
            raise Rejected(429, "Printer queue full")

    def status(self):
        return dict(
            available=self.available,
            accepting_jobs=self.accepting_jobs and len(self.pending) < self.queue_size,
            state=(
                "maintenance"
                if self.maintenance
                else "printing" if self.active else self.health
            ),
            connected=self.transport.connected,
            flags=self.transport.flags,
            seconds_since_reply=round(time.monotonic() - self.transport.last_reply, 1)
            if self.transport.last_reply
            else None,
            active_job=self.active,
            queued=len(self.pending),
            queue_full=len(self.pending) >= self.queue_size,
            last_error=self.last_error,
            remote_wake_supported=False,
        )

    def submit(self, image, options, client="app", key=None, *, job_id=None):
        if key:
            previous = self.history.by_key(key)
            if previous:
                return previous
        self.check_submission()
        if job_id is None:
            job_id = str(uuid.uuid4())
        self.history.add(job_id, image.height, client, options, key)
        self.images[job_id] = image
        self.pending.append((job_id, time.monotonic()))
        self.changed.set()
        return self.history.get(job_id)

    def cancel(self, job_id):
        if job_id == self.active:
            raise Rejected(409, "Cannot safely cancel an active physical print")
        job = self.history.get(job_id)
        if job is None:
            raise Rejected(404, "Unknown job")
        if job["state"] == "queued":
            self.pending = deque((j, t) for j, t in self.pending if j != job_id)
            self.finish(job_id, "cancelled", "client_cancelled")
        return self.history.get(job_id)

    def finish(self, job_id, state, reason=None):
        self.images.pop(job_id, None)
        self.history.set(job_id, state, reason)

    def fail_pending(self, reason, state="failed"):
        while self.pending:
            job_id, _ = self.pending.popleft()
            self.finish(job_id, state, reason)

    async def set_maintenance(self, enabled):
        if enabled and self.active:
            raise Rejected(409, "Wait for the active print before maintenance")
        self.maintenance = enabled
        self.changed.set()
        if enabled:
            self.fail_pending("maintenance", "cancelled")
            await asyncio.wait_for(self.released.wait(), 65)
        return self.status()

    async def start(self):
        self.task = asyncio.create_task(self.run())
        self.task.add_done_callback(self.worker_done)

    @staticmethod
    def worker_done(task):
        if not task.cancelled() and task.exception() is not None:
            LOG.critical(
                "Printer worker stopped unexpectedly; terminating for systemd recovery"
            )
            # A live HTTP listener without its BLE owner is not a healthy
            # appliance. SystemExit escapes the event-loop callback and causes
            # a nonzero process exit; systemd restarts and reconciles metadata.
            raise SystemExit(1)

    async def stop(self):
        if self.task:
            self.task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.task
        if self.active:
            state = self.history.get(self.active)["state"]
            self.finish(
                self.active,
                "uncertain" if state == "printing" else "cancelled",
                "service_stop",
            )
        self.fail_pending("service_stop", "cancelled")
        await self.transport.close()
        self.history.db.close()

    async def wait(self, seconds):
        try:
            await asyncio.wait_for(self.changed.wait(), seconds)
        except asyncio.TimeoutError:
            pass
        self.changed.clear()

    async def probe(self):
        try:
            await self.transport.connect()
            flags = await self.transport.status()
            self.health = (
                "fault" if flags & 0x0F else "busy" if flags & 0x80 else "ready"
            )
            self.last_error = "printer_fault" if flags & 0x0F else None
            if flags & 0x0F:
                self.fail_pending("printer_unavailable")
            return 2 if flags & 0x80 else self.interval
        except Exception:
            self.health, self.last_error = "unavailable", "no_status_response"
            self.fail_pending("printer_unavailable")
            await self.transport.close()
            return 10

    async def run(self):
        while True:
            if time.monotonic() - self.last_prune > 3600:
                self.history.prune()
                self.last_prune = time.monotonic()
            if self.maintenance:
                await self.transport.close()
                self.released.set()
                await self.wait(30)
                continue
            self.released.clear()
            if self.pending:
                while (
                    self.pending and time.monotonic() - self.pending[0][1] > self.expiry
                ):
                    job_id, _ = self.pending.popleft()
                    self.finish(job_id, "expired", "queue_expired")
                if not self.pending:
                    continue
                if not self.available:
                    delay = await self.probe()
                    if not self.available:
                        await self.wait(delay)
                    # Recheck expiry, cancellations and maintenance after yielding.
                    continue
                job_id, _ = self.pending.popleft()
                self.active = job_id
                self.history.set(job_id, "preparing")
                try:
                    image = self.images[job_id]
                    outcome = await self.transport.print_job(
                        image, lambda: self.history.set(job_id, "printing")
                    )
                    self.finish(job_id, outcome)
                    if outcome == "sent":
                        self.health = "busy"
                except asyncio.CancelledError:
                    state = self.history.get(job_id)["state"]
                    self.finish(
                        job_id,
                        "uncertain" if state == "printing" else "cancelled",
                        "service_stop",
                    )
                    raise
                except Exception:
                    state = self.history.get(job_id)["state"]
                    self.finish(
                        job_id,
                        "uncertain" if state == "printing" else "failed",
                        "print_interrupted",
                    )
                    self.health, self.last_error = "unavailable", "print_interrupted"
                    self.fail_pending("printer_unavailable")
                    await self.transport.close()
                finally:
                    # Do not retain the payload via a worker-local reference.
                    image = None
                    self.active = None
                # MX10's per-job lifecycle includes releasing the completed
                # session. Reacquire immediately for keepalive; never leave a
                # stale busy latch or a second job on the previous session.
                await self.transport.close()
                if not self.maintenance:
                    await self.probe()
                continue
            delay = await self.probe()
            # A maintenance request may have arrived during connect/status.
            if self.maintenance:
                continue
            await self.wait(delay)
