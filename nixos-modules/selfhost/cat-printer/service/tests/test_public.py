import re
import tempfile
import time
import unittest
from types import SimpleNamespace

from aiohttp import ClientSession, UnixConnector, web
from aiohttp.test_utils import TestClient, TestServer
from PIL import Image
from pylibdmtx.pylibdmtx import decode

from catprinter.render import Renderer, png
from catprinter.server import PUBLIC_GET_PATHS, create_app
from catprinter.service import History, Service


class IdleService(Service):
    """Real submission/history behavior without a BLE worker or physical prints."""

    async def start(self):
        pass

    async def stop(self):
        pass


class PublicPrintingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.history = History(self.directory.name + "/jobs.sqlite")
        transport = SimpleNamespace(
            connected=True, last_reply=time.monotonic(), flags=0
        )
        self.service = IdleService(transport, self.history)
        self.service.health = "ready"
        self.client = TestClient(
            TestServer(
                create_app(
                    self.service,
                    Renderer(),
                    public_expires_at=int(time.time()) + 3600,
                )
            )
        )
        await self.client.start_server()
        self.socket = self.directory.name + "/printer.sock"
        await web.UnixSite(self.client.server.runner, self.socket).start()
        self.public = ClientSession(connector=UnixConnector(path=self.socket))
        self.headers = {
            "X-Browser-Identity": "a" * 64,
            "Content-Type": "image/png",
            "X-Catprinter-Client-IP": "203.0.113.9",
        }
        self.image = Image.new("1", (384, 8), 0)
        self.body = png(self.image)

    async def asyncTearDown(self):
        await self.public.close()
        await self.client.close()
        self.history.db.close()
        self.directory.cleanup()

    async def test_private_tcp_ignores_public_ip_header(self):
        response = await self.client.post(
            "/ui/api/jobs/image", data=self.body, headers=self.headers
        )
        self.assertEqual(response.status, 202)
        job = await response.json()
        self.assertRegex(job["id"], r"^[0-9a-f-]{36}$")
        self.assertEqual(self.service.images[job["id"]].size, self.image.size)

    async def test_busy_public_api_acknowledges_queued_submission(self):
        self.service.health = "busy"
        self.service.transport.flags = 0x80
        response = await self.public.get(
            "http://localhost/ui/api/status", headers=self.headers
        )
        status = await response.json()
        self.assertFalse(status["available"])
        self.assertTrue(status["accepting_jobs"])
        response = await self.public.post(
            "http://localhost/ui/api/jobs/image", data=self.body, headers=self.headers
        )
        self.assertEqual(response.status, 202)
        job = await response.json()
        self.assertEqual(job["state"], "queued")
        self.assertEqual(len(self.service.pending), 1)

    async def test_public_footer_matches_persisted_job(self):
        response = await self.public.post(
            "http://localhost/ui/api/jobs/image", data=self.body, headers=self.headers
        )
        self.assertEqual(response.status, 202)
        job = await response.json()
        self.assertRegex(job["id"], r"^[0-9]{20}$")
        printed = self.service.images[job["id"]]
        self.assertEqual(printed.size, (384, 64))
        self.assertEqual(printed.crop((0, 0, 384, 8)).tobytes(), self.image.tobytes())
        self.assertEqual(
            decode(printed.convert("RGB"), timeout=1000)[0].data.decode(), job["id"]
        )
        self.assertEqual(self.history.get(job["id"])["rows"], printed.height)

    async def test_public_rotation_includes_footer_before_content(self):
        response = await self.public.post(
            "http://localhost/ui/api/jobs/image?rotation=180",
            data=self.body,
            headers=self.headers,
        )
        self.assertEqual(response.status, 202)
        job = await response.json()
        printed = self.service.images[job["id"]]
        self.assertEqual(printed.size, (384, 64))
        self.assertEqual(printed.crop((0, 56, 384, 64)).tobytes(), self.image.tobytes())
        self.assertNotEqual(printed.crop((0, 0, 384, 8)).tobytes(), self.image.tobytes())
        upright = printed.transpose(Image.Transpose.ROTATE_180)
        self.assertEqual(upright.crop((0, 0, 384, 8)).tobytes(), self.image.tobytes())
        self.assertEqual(decode(printed.convert("RGB"), timeout=1000)[0].data.decode(), job["id"])

    async def test_public_socket_cannot_access_private_api(self):
        for method, path in (
            ("GET", "/v1/jobs"),
            ("GET", "/ui/api/jobs"),
            ("POST", "/v1/maintenance"),
            ("DELETE", "/ui/api/jobs/x"),
        ):
            response = await self.public.request(
                method, "http://localhost" + path, headers=self.headers
            )
            self.assertEqual(response.status, 404, path)

    async def test_public_client_ip_is_required_and_validated(self):
        for ip in ("", "invalid"):
            headers = dict(self.headers, **{"X-Catprinter-Client-IP": ip})
            response = await self.public.post(
                "http://localhost/ui/api/jobs/image", data=self.body, headers=headers
            )
            self.assertEqual(response.status, 400)
        self.assertEqual(self.history.list(), [])

    async def test_large_images_are_private_only(self):
        body = png(Image.new("1", (5000, 4000), 1))  # 20 MP, small wire payload.
        for endpoint, expected in (("preview", 200), ("jobs", 202)):
            response = await self.client.post(
                f"/v1/{endpoint}/image",
                data=body,
                headers={"Content-Type": "image/png"},
            )
            self.assertEqual(response.status, expected)
            response = await self.public.post(
                f"http://localhost/ui/api/{endpoint}/image",
                data=body,
                headers=self.headers,
            )
            self.assertEqual(response.status, 400)
        self.assertEqual(len(self.service.pending), 1)

    async def test_public_preview_remains_content_only(self):
        response = await self.public.post(
            "http://localhost/ui/api/preview/image",
            data=self.body,
            headers=self.headers,
        )
        self.assertEqual(response.status, 200)
        self.assertEqual(response.headers["X-Print-Rows"], "8")
        self.assertEqual(response.headers["X-Paper-Length-MM"], "13.5")
        self.assertEqual(self.history.list(), [])

    async def test_public_idempotency_does_not_queue_twice(self):
        headers = dict(self.headers, **{"Idempotency-Key": "same-print"})
        jobs = []
        for expected in (202, 200):
            response = await self.public.post(
                "http://localhost/ui/api/jobs/image", data=self.body, headers=headers
            )
            self.assertEqual(response.status, expected)
            jobs.append(await response.json())
        self.assertEqual(jobs[0]["id"], jobs[1]["id"])
        self.assertEqual(len(self.service.pending), 1)

    async def test_all_public_assets_are_available(self):
        for path in PUBLIC_GET_PATHS - {"/ui/api/status"}:
            response = await self.public.get("http://localhost" + path)
            self.assertEqual(response.status, 200, path)
            self.assertTrue(await response.read(), path)
        response = await self.public.get("http://localhost/")
        html = await response.text()
        for asset in re.findall(r'(?:src|href)="(/ui/static/[^"#]+)"', html):
            self.assertIn(asset, PUBLIC_GET_PATHS)

    async def test_public_image_decoder_and_csp(self):
        for asset in ("image-decode.js", "heic-to.js"):
            response = await self.public.get("http://localhost/ui/static/" + asset)
            self.assertEqual(response.status, 200)
            policy = response.headers["Content-Security-Policy"]
            self.assertIn("worker-src 'self' blob:", policy)
            self.assertNotIn("unsafe-eval", policy)
            self.assertNotIn("unsafe-inline", policy)
        response = await self.public.get(
            "http://localhost/ui/static/manifest.webmanifest"
        )
        manifest = await response.json()
        accepted = manifest["share_target"]["params"]["files"][0]["accept"]
        self.assertIn("image/*", accepted)
        self.assertIn(".heic", accepted)

    async def test_expired_public_socket_fails_closed_private_stays_available(self):
        client = TestClient(
            TestServer(create_app(self.service, Renderer(), public_expires_at=1))
        )
        async with client:
            path = self.directory.name + "/expired.sock"
            await web.UnixSite(client.server.runner, path).start()
            async with ClientSession(connector=UnixConnector(path=path)) as public:
                response = await public.get("http://localhost/")
                self.assertEqual(response.status, 410)
            response = await client.get("/healthz")
            self.assertEqual(response.status, 200)


if __name__ == "__main__":
    unittest.main()
