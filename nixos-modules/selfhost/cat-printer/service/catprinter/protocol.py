"""MX10 old-kind protocol: raw A2 rows, never BF or captured BC frames.

Sequence informed by s8n/cataclysm (MIT), src/lib/printer/protocol.ts,
revision b6484df0cd9b0469304a106b42d27539876da6c7; see NOTICE.
"""

import asyncio
import contextlib
import time

from bleak import BleakClient, BleakScanner
from bleak.backends.device import BLEDevice

WIDTH = 384
TX = "0000ae01-0000-1000-8000-00805f9b34fb"
RX = "0000ae02-0000-1000-8000-00805f9b34fb"
LATTICE_START = bytes.fromhex("aa551738445f5f5f44382c")
LATTICE_END = bytes.fromhex("aa55170000000000000017")


def crc8(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ (7 if crc & 128 else 0)) & 255
    return crc


def frame(cmd, data=b"\0", direction=0):
    return (
        b"Qx"
        + bytes([cmd, direction])
        + len(data).to_bytes(2, "little")
        + data
        + bytes([crc8(data), 255])
    )


class Decoder:
    def __init__(self):
        self.buffer = bytearray()

    def feed(self, raw):
        self.buffer.extend(raw)
        frames = []
        while len(self.buffer) >= 8:
            if self.buffer[:2] != b"Qx":
                del self.buffer[0]
                continue
            length = int.from_bytes(self.buffer[4:6], "little")
            if length > 512:
                del self.buffer[0]
                continue
            if len(self.buffer) < length + 8:
                break
            data = bytes(self.buffer[: length + 8])
            if data[-1] != 255 or crc8(data[6:-2]) != data[-2]:
                del self.buffer[0]
                continue
            del self.buffer[: length + 8]
            if data[3] == 1:
                frames.append((data[2], data[6:-2]))
        return frames


def bitmap_row(row):
    # Pillow mode 1 packs MSB-first, whereas the printer is LSB-first.
    packed = bytearray(48)
    for x, pixel in enumerate(row):
        if not pixel:
            packed[x // 8] |= 1 << (x % 8)
    return frame(0xA2, bytes(packed))


def build_job(image):
    if image.width != WIDTH or image.mode != "1":
        raise ValueError("Expected a 384px-wide monochrome image")
    parts = [
        frame(0xA3),
        frame(0xA3),
        frame(0xA4, b"\x33"),
        frame(0xBD, b"\x20"),
        frame(0xAF, (24000).to_bytes(2, "little")),
        frame(0xBE),
        frame(0xA9),
        frame(0xA6, LATTICE_START),
    ]
    blank = frame(0xA2, bytes(48))
    parts.append(blank * 48)
    pixels = list(image.get_flattened_data())
    for y in range(image.height):
        parts.append(bitmap_row(pixels[y * WIDTH : (y + 1) * WIDTH]))
    parts.extend(
        [frame(0xBD, b"\x19"), blank * 100, frame(0xA6, LATTICE_END), frame(0xA3)]
    )
    return b"".join(parts)


class Transport:
    def __init__(self, address, adapter="hci0"):
        self.address, self.adapter = address, adapter
        self.client = None
        self.decoder = Decoder()
        self.responses = asyncio.Queue()
        self.flow = asyncio.Event()
        self.flow.set()
        self.flags = None
        self.last_reply = 0
        self.gone = asyncio.Event()

    @property
    def connected(self):
        return bool(self.client and self.client.is_connected and not self.gone.is_set())

    def receive(self, _, raw):
        for cmd, payload in self.decoder.feed(raw):
            if cmd == 0xAE and payload:
                if payload[0] & 0x0F:
                    self.flags = (self.flags or 0) | (payload[0] & 0x0F)
                if payload[0] & 0x10:
                    self.flow.clear()
                else:
                    self.flow.set()
            if cmd == 0xA3 and payload:
                self.flags = payload[0]
                self.last_reply = time.monotonic()
                self.responses.put_nowait(payload[0])

    async def close(self):
        client, self.client = self.client, None
        self.last_reply = 0
        if client:
            with contextlib.suppress(Exception):
                await client.disconnect()

    async def connect(self, fresh=False):
        if fresh:
            await self.close()
            await asyncio.sleep(1)
        if self.connected:
            return
        self.decoder = Decoder()
        self.gone = asyncio.Event()
        self.flow.set()
        # Do not scan an already-connected printer: it need not advertise.
        path = f"/org/bluez/{self.adapter}/dev_" + self.address.replace(":", "_")
        target = BLEDevice(self.address, "MX10", {"path": path})
        self.client = BleakClient(
            target,
            timeout=20,
            disconnected_callback=lambda _, event=self.gone: event.set(),
        )
        try:
            await self.client.connect()
            # BlueZ/Bleak can emit a disconnect callback for an aborted
            # intermediate attempt, then recover inside connect(). Only the
            # final successful connection is authoritative here.
            self.gone.clear()
            await self.client.start_notify(RX, self.receive)
        except Exception:
            await self.close()
            # Discovery is needed after BlueZ has forgotten the device object.
            found = await BleakScanner.find_device_by_address(
                self.address, timeout=5, bluez={"adapter": self.adapter}
            )
            if found is None:
                raise ConnectionError("Printer not reachable") from None
            self.gone = asyncio.Event()
            self.client = BleakClient(
                found,
                timeout=20,
                disconnected_callback=lambda _, event=self.gone: event.set(),
            )
            try:
                await self.client.connect()
                self.gone.clear()
                await self.client.start_notify(RX, self.receive)
            except BaseException:
                await self.close()
                raise

    async def status(self):
        if not self.connected:
            raise ConnectionError("Printer disconnected")
        while not self.responses.empty():
            self.responses.get_nowait()
        await self.client.write_gatt_char(TX, frame(0xA3), response=False)
        return await asyncio.wait_for(self.responses.get(), 8)

    async def print_job(self, image, started):
        await self.connect(fresh=True)
        flags = await self.status()
        if flags & 0x8F:
            raise ConnectionError("Printer not ready before print")
        data = build_job(image)
        chunk = min(
            63,
            self.client.services.get_characteristic(TX).max_write_without_response_size,
        )
        # Persist uncertainty BEFORE the first write; a failed write may still
        # have reached the printer. Never retry this stream automatically.
        started()
        deadline = time.monotonic() + max(180, len(data) / chunk * 0.04 + 30)
        for offset in range(0, len(data), chunk):
            if time.monotonic() > deadline:
                raise TimeoutError("Print transfer deadline exceeded")
            await asyncio.wait_for(self.flow.wait(), 15)
            if not self.connected:
                raise ConnectionError("Disconnected during print")
            if self.flags is not None and self.flags & 0x0F:
                raise ConnectionError("Printer fault during print")
            await self.client.write_gatt_char(
                TX, data[offset : offset + chunk], response=False
            )
            await asyncio.sleep(0.02)
        # No request/ack checkpoints mid-job: MX10 may defer those replies.
        await asyncio.sleep(3)
        for _ in range(10):
            flags = await self.status()
            if flags & 0x0F:
                raise ConnectionError("Printer fault after transfer")
            if not flags & 0x80:
                return "finished"
            await asyncio.sleep(1)
        # All writes completed, but physical completion was not confirmed.
        return "sent"
