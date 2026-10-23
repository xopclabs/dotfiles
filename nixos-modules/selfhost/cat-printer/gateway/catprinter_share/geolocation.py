"""Best-effort public-IP location lookup; never required for printing."""

import ipaddress
import json
import time
from collections import OrderedDict

from aiohttp import ClientError, ClientTimeout


class Geolocation:
    def __init__(self, session):
        self.session = session
        self.cache = OrderedDict()

    async def lookup(self, address):
        ip = ipaddress.ip_address(address)
        if not ip.is_global or ip.is_multicast:
            return None
        address = str(ip)
        cached = self.cache.get(address)
        if cached and cached[0] > time.monotonic():
            self.cache.move_to_end(address)
            return cached[1]
        try:
            location = await self.fetch(address)
        except (ClientError, TimeoutError, ValueError, TypeError, AttributeError):
            location = None
        # Cache misses too, so an outage doesn't delay every print by two seconds.
        self.cache[address] = (time.monotonic() + (86400 if location else 600), location)
        self.cache.move_to_end(address)
        while len(self.cache) > 256:
            self.cache.popitem(last=False)
        return location

    async def fetch(self, address):
        async with self.session.get(
            f"https://ip.guide/{address}",
            headers={"Accept": "application/json"},
            timeout=ClientTimeout(total=2),
            allow_redirects=False,
        ) as response:
            if response.status != 200:
                return None
            raw = bytearray()
            async for chunk in response.content.iter_chunked(4096):
                raw.extend(chunk)
                if len(raw) > 8192:
                    return None
            data = json.loads(raw)
        location = data.get("location")
        if not isinstance(location, dict):
            return None
        parts = []
        for key in ("city", "country"):
            value = location.get(key)
            if isinstance(value, str):
                value = " ".join(value.split())
                if value and len(value) <= 80 and value.isprintable():
                    parts.append(value)
        return ", ".join(parts) or None
