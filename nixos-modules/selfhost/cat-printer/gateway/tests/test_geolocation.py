import json
import time
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from catprinter_share.geolocation import Geolocation


class GeolocationTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.session = MagicMock()
        self.locator = Geolocation(self.session)

    def reply(self, data, status=200):
        raw = data if isinstance(data, bytes) else json.dumps(data).encode()

        async def chunks(_):
            for offset in range(0, len(raw), 100):
                yield raw[offset:offset + 100]

        response = SimpleNamespace(
            status=status, content=SimpleNamespace(iter_chunked=chunks)
        )
        self.session.get.return_value.__aenter__ = AsyncMock(return_value=response)
        self.session.get.return_value.__aexit__ = AsyncMock(return_value=False)

    async def test_location_is_cached_and_uses_fixed_https_origin(self):
        self.reply({"location": {"city": "  Madrid\n", "country": "Spain"}})
        for _ in range(2):
            self.assertEqual(await self.locator.lookup("8.8.8.8"), "Madrid, Spain")
        self.session.get.assert_called_once()
        args, kwargs = self.session.get.call_args
        self.assertEqual(args[0], "https://ip.guide/8.8.8.8")
        self.assertFalse(kwargs["allow_redirects"])
        self.assertEqual(kwargs["timeout"].total, 2)

    async def test_non_public_addresses_never_leave_host(self):
        for address in ("127.0.0.1", "10.0.0.1", "192.168.1.1", "203.0.113.9", "::1"):
            self.assertIsNone(await self.locator.lookup(address))
        self.session.get.assert_not_called()

    async def test_failure_is_cached_but_expires(self):
        self.locator.fetch = AsyncMock(side_effect=TimeoutError)
        for _ in range(2):
            self.assertIsNone(await self.locator.lookup("8.8.8.8"))
        self.locator.fetch.assert_awaited_once()
        self.locator.cache["8.8.8.8"] = (time.monotonic() - 1, None)
        self.locator.fetch = AsyncMock(return_value="Spain")
        self.assertEqual(await self.locator.lookup("8.8.8.8"), "Spain")

    async def test_bad_responses_do_not_block_printing(self):
        for response in (b"not json", b"x" * 9000, [], {}, {"location": []}):
            self.locator.cache.clear()
            self.reply(response)
            self.assertIsNone(await self.locator.lookup("8.8.8.8"))
        self.locator.cache.clear()
        self.reply({}, status=429)
        self.assertIsNone(await self.locator.lookup("8.8.8.8"))

    async def test_country_only_and_missing_location(self):
        self.reply({"location": {"city": None, "country": "Spain"}})
        self.assertEqual(await self.locator.lookup("8.8.8.8"), "Spain")
        self.reply({"location": {"city": None, "country": None}})
        self.assertIsNone(await self.locator.lookup("9.9.9.9"))

    async def test_cache_is_bounded(self):
        self.locator.fetch = AsyncMock(return_value="Spain")
        for number in range(257):
            await self.locator.lookup(f"8.8.{number // 256}.{number % 256}")
        self.assertEqual(len(self.locator.cache), 256)
