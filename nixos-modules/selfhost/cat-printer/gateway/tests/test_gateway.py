import asyncio
import tempfile
import unittest
from unittest.mock import AsyncMock

from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

from catprinter_share import GEOLOCATION, create_app


class GatewayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.calls = []
        self.now = 100

        async def backend(request):
            self.calls.append(
                (
                    request.method,
                    request.path,
                    dict(request.headers),
                    await request.read(),
                )
            )
            if request.query.get("redirect"):
                raise web.HTTPFound("http://127.0.0.1:1/secret")
            return web.Response(text="ok", headers={"X-Private": "hidden"})

        app = web.Application()
        app.router.add_route("*", "/{path:.*}", backend)
        self.directory = tempfile.TemporaryDirectory()
        self.socket = self.directory.name + "/printer.sock"
        self.backend = web.AppRunner(app)
        await self.backend.setup()
        await web.UnixSite(self.backend, self.socket).start()
        self.gateway = TestClient(
            TestServer(
                create_app(
                    self.socket,
                    200,
                    trusted_proxy="127.0.0.1",
                    clock=lambda: self.now,
                )
            )
        )
        await self.gateway.start_server()

    async def asyncTearDown(self):
        await self.gateway.close()
        await self.backend.cleanup()
        self.directory.cleanup()

    async def test_forwarding_and_header_boundary(self):
        response = await self.gateway.post(
            "/ui/api/jobs",
            data=b"print",
            headers={
                "Content-Type": "application/json",
                "X-Forwarded-For": "198.51.100.1, 203.0.113.9",
                "X-Catprinter-Client-IP": "192.0.2.99",
                "Authorization": "Bearer must-not-forward",
                "Cookie": "must-not-forward",
            },
        )
        self.assertEqual(response.status, 200)
        self.assertNotIn("X-Private", response.headers)
        method, path, headers, body = self.calls[0]
        self.assertEqual((method, path, body), ("POST", "/ui/api/jobs", b"print"))
        self.assertEqual(headers["X-Catprinter-Client-IP"], "203.0.113.9")
        self.assertNotIn("Authorization", headers)
        self.assertNotIn("Cookie", headers)

    async def test_location_header_is_relay_generated_for_jobs_only(self):
        locator = self.gateway.server.app[GEOLOCATION]
        locator.lookup = AsyncMock(return_value="Madrid, Spain")
        headers = {
            "X-Forwarded-For": "8.8.8.8",
            "X-Catprinter-Location": "Spoofed location",
        }
        response = await self.gateway.post("/ui/api/jobs/image", headers=headers)
        self.assertEqual(response.status, 200)
        self.assertEqual(self.calls[-1][2]["X-Catprinter-Location"], "Madrid, Spain")
        response = await self.gateway.post("/ui/api/preview/image", headers=headers)
        self.assertEqual(response.status, 200)
        self.assertNotIn("X-Catprinter-Location", self.calls[-1][2])
        locator.lookup.assert_awaited_once_with("8.8.8.8")

    async def test_lazy_image_decoder_assets_reach_backend(self):
        for asset in ("image-decode.js", "heic-to.js", "heic-to.LICENSE"):
            path = "/ui/static/" + asset
            for method in ("GET", "HEAD"):
                response = await self.gateway.request(method, path)
                self.assertEqual(response.status, 200, path)
                self.assertEqual(self.calls[-1][:2], (method, path))
        response = await self.gateway.get("/ui/static/not-allowed.js")
        self.assertEqual(response.status, 404)
        self.assertEqual(len(self.calls), 6)

    async def test_private_routes_and_wrong_methods_never_reach_backend(self):
        for method, path in (
            ("GET", "/v1/jobs"),
            ("POST", "/v1/maintenance"),
            ("DELETE", "/ui/api/jobs"),
            ("GET", "/ui/api/jobs"),
            ("POST", "/ui/api/status"),
            ("GET", "/ui/static/../api/status"),
            ("GET", "/ui/api/%73tatus"),
        ):
            with self.subTest(method=method, path=path):
                # Raw socket avoids client-side dot-segment/percent normalization.
                reader, writer = await asyncio.open_connection(
                    "127.0.0.1", self.gateway.port
                )
                writer.write(
                    (
                        f"{method} {path} HTTP/1.1\r\n"
                        "Host: localhost\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    ).encode()
                )
                await writer.drain()
                status = await reader.readline()
                await reader.read()
                writer.close()
                await writer.wait_closed()
                self.assertEqual(status.split()[1], b"404")
        self.assertEqual(self.calls, [])

    async def test_expiry_is_absolute_and_inclusive(self):
        self.now = 199
        self.assertEqual((await self.gateway.get("/ui/api/status")).status, 200)
        self.now = 200
        for path in ("/", "/ui/api/jobs"):
            self.assertEqual((await self.gateway.post(path)).status, 410)
        self.assertEqual(len(self.calls), 1)

    async def test_redirect_is_not_followed(self):
        response = await self.gateway.get("/?redirect=1")
        self.assertEqual(response.status, 502)
        self.assertEqual(len(self.calls), 1)

    async def test_untrusted_proxy_is_rejected(self):
        gateway = TestClient(
            TestServer(
                create_app(self.socket, 200, "192.0.2.1", clock=lambda: self.now)
            )
        )
        async with gateway:
            response = await gateway.get("/")
            self.assertEqual(response.status, 403)
        self.assertEqual(self.calls, [])

    async def test_missing_backend_is_unavailable(self):
        await self.backend.cleanup()
        response = await self.gateway.get("/")
        self.assertEqual(response.status, 502)

    async def test_oversized_body_never_reaches_backend(self):
        response = await self.gateway.post(
            "/ui/api/jobs", data=b"x" * (8 * 1024 * 1024 + 1)
        )
        self.assertEqual(response.status, 413)
        self.assertEqual(self.calls, [])

    async def test_expiry_during_upload_never_reaches_backend(self):
        async def body():
            yield b"first"
            self.now = 200
            yield b"last"

        response = await self.gateway.post("/ui/api/jobs", data=body())
        self.assertEqual(response.status, 410)
        self.assertEqual(self.calls, [])

    async def test_malformed_forwarded_ip_is_rejected(self):
        response = await self.gateway.get("/", headers={"X-Forwarded-For": "invalid"})
        self.assertEqual(response.status, 400)
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
