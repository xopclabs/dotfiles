"""HTTP API: POST /v1/jobs or /v1/jobs/image; POST /v1/preview[/image].

Markdown requests: {"markdown":"# Hello", "options":{"rotation":0}}.
Rotation defaults to 0 for text and images; use 180 explicitly to flip.
Images: raw PNG/JPEG/WebP body; rendering options are query parameters.
GET /v1/status, GET /v1/jobs[/id], DELETE /v1/jobs/id.
POST /v1/maintenance: {"enabled":true}. No endpoints fetch remote content.
"""

import argparse
import asyncio
import hashlib
import json
import logging
import os
import re
import socket
from pathlib import Path
from urllib.parse import urlsplit

from aiohttp import web
from .protocol import Transport
from .render import InvalidContent, Options, Renderer, png
from .service import History, Rejected, Service

SERVICE = web.AppKey("service", Service)
RENDERER = web.AppKey("renderer", Renderer)
RENDER_SLOTS = web.AppKey("render_slots", asyncio.Semaphore)


@web.middleware
async def safety(request, handler):
    browser = bool(
        request.headers.get("Origin") or request.headers.get("Sec-Fetch-Site")
    )
    origin = request.headers.get("Origin")
    foreign = request.headers.get("Sec-Fetch-Site") in ("cross-site", "same-site")
    if origin:
        try:
            parsed = urlsplit(origin)
            foreign = (
                foreign
                or parsed.scheme not in ("http", "https")
                or parsed.netloc != request.host
            )
        except ValueError:
            foreign = True
    if (request.path.startswith("/v1/") and browser) or (
        request.path.startswith("/ui/api/") and foreign
    ):
        return web.json_response({"error": "Browser access denied"}, status=403)
    try:
        response = await handler(request)
    except Rejected as exc:
        response = web.json_response({"error": str(exc)}, status=exc.status)
    except TimeoutError:
        response = web.json_response({"error": "Request body timeout"}, status=408)
    except (InvalidContent, ValueError, TypeError, json.JSONDecodeError):
        response = web.json_response(
            {"error": "Invalid content or request options"}, status=400
        )
    except web.HTTPException:
        raise
    except Exception:
        # Do not log request bodies, source text, images, or rendering traces.
        logging.getLogger(__name__).error(
            "Request failed: %s %s", request.method, request.path
        )
        response = web.json_response({"error": "Internal service error"}, status=500)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; img-src 'self' blob:; object-src 'none'; "
        "base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
    )
    return response


async def json_body(request):
    if request.content_type != "application/json":
        raise web.HTTPUnsupportedMediaType()
    async with asyncio.timeout(15):
        value = await request.json()
    if not isinstance(value, dict):
        raise InvalidContent("Expected a JSON object")
    return value


async def render_request(request):
    if request.app[RENDER_SLOTS].locked():
        raise Rejected(429, "Renderer busy")
    async with request.app[RENDER_SLOTS]:
        renderer = request.app[RENDERER]
        if request.path.endswith("/image"):
            if request.content_type not in ("image/png", "image/jpeg", "image/webp"):
                raise web.HTTPUnsupportedMediaType()
            options = dict(request.query)
            for key in ("rotation", "font_size"):
                if key in options:
                    options[key] = int(options[key])
            options = Options.parse(options)
            async with asyncio.timeout(15):
                raw = await request.read()
            image = await asyncio.to_thread(renderer.image, raw, options)
        else:
            value = await json_body(request)
            if value.keys() - {"markdown", "options"}:
                raise InvalidContent("Unknown request fields")
            options = Options.parse(value.get("options", {}))
            image = await asyncio.to_thread(
                renderer.markdown, value.get("markdown"), options
            )
        return image, options


async def submit(request):
    service = request.app[SERVICE]
    key = request.headers.get("Idempotency-Key")
    owner = browser_owner(request) if request.path.startswith("/ui/api/") else None
    client = owner or request.headers.get("X-Printer-Client", "app")
    if owner and key:
        if not 1 <= len(key) <= 128:
            raise InvalidContent("Invalid idempotency key")
        key = hashlib.sha256((owner + key).encode()).hexdigest()
    if len(client) > 64 or (key is not None and not 1 <= len(key) <= 128):
        raise InvalidContent("Invalid client label or idempotency key")
    previous = service.history.by_key(key)
    if previous:
        # Keys identify submissions, not reprint requests. To reprint, submit
        # the content again with a NEW key; no retained payload exists.
        return web.json_response(previous, status=200)
    if not service.available:
        raise Rejected(503, "Printer unavailable; no job was queued")
    image, options = await render_request(request)
    result = service.submit(image, options, client, key)
    return web.json_response(
        result, status=202, headers={"Location": "/v1/jobs/" + result["id"]}
    )


async def preview(request):
    image, _ = await render_request(request)
    return web.Response(
        body=png(image),
        content_type="image/png",
        headers={
            "X-Print-Rows": str(image.height),
            "X-Paper-Length-MM": str(round((image.height + 100) / 8, 1)),
        },
    )


async def status(request):
    value = request.app[SERVICE].status()
    if request.path.startswith("/ui/api/"):
        browser_owner(request)
        value = {key: value[key] for key in ("available", "state", "connected")}
    return web.json_response(value)


async def health(request):
    return web.json_response({"alive": True})


async def jobs(request):
    owner = browser_owner(request) if request.path.startswith("/ui/api/") else None
    return web.json_response(request.app[SERVICE].history.list(owner))


async def job(request):
    result = request.app[SERVICE].history.get(request.match_info["id"])
    if result is None:
        raise web.HTTPNotFound()
    return web.json_response(result)


async def cancel(request):
    if request.path.startswith("/ui/api/"):
        owner = browser_owner(request)
        value = request.app[SERVICE].history.get(request.match_info["id"])
        if value is None or value["client"] != owner:
            raise web.HTTPNotFound()
    return web.json_response(request.app[SERVICE].cancel(request.match_info["id"]))


def browser_owner(request):
    token = request.headers.get("X-Browser-Identity", "")
    if not re.fullmatch(r"[a-f0-9]{64}", token):
        raise web.HTTPForbidden()
    return hashlib.sha256(token.encode()).hexdigest()


async def browser_preview(request):
    browser_owner(request)
    return await preview(request)


async def index(request):
    return web.FileResponse(Path(__file__).parent / "static" / "index.html")


async def service_worker(request):
    response = web.FileResponse(Path(__file__).parent / "static" / "sw.js")
    response.headers["Cache-Control"] = "no-cache"
    return response


async def maintenance(request):
    value = await json_body(request)
    if set(value) != {"enabled"} or type(value["enabled"]) is not bool:
        raise InvalidContent("Expected enabled: boolean")
    return web.json_response(
        await request.app[SERVICE].set_maintenance(value["enabled"])
    )


def create_app(service, renderer):
    app = web.Application(middlewares=[safety], client_max_size=8 * 1024 * 1024)
    app[SERVICE], app[RENDERER] = service, renderer
    app[RENDER_SLOTS] = asyncio.Semaphore(1)
    app.add_routes(
        [
            web.get("/", index),
            web.get("/sw.js", service_worker),
            web.get("/ui/api/status", status),
            web.get("/ui/api/jobs", jobs),
            web.delete("/ui/api/jobs/{id}", cancel),
            web.post("/ui/api/jobs", submit),
            web.post("/ui/api/jobs/image", submit),
            web.post("/ui/api/preview", browser_preview),
            web.post("/ui/api/preview/image", browser_preview),
            web.static("/ui/static/", Path(__file__).parent / "static"),
            web.get("/healthz", health),
            web.get("/v1/status", status),
            web.get("/v1/jobs", jobs),
            web.get("/v1/jobs/{id}", job),
            web.delete("/v1/jobs/{id}", cancel),
            web.post("/v1/jobs", submit),
            web.post("/v1/jobs/image", submit),
            web.post("/v1/preview", preview),
            web.post("/v1/preview/image", preview),
            web.post("/v1/maintenance", maintenance),
        ]
    )

    async def lifecycle(_):
        await service.start()
        try:
            yield
        finally:
            await service.stop()

    app.cleanup_ctx.append(lifecycle)
    return app


def inherited_socket():
    if (
        os.environ.get("LISTEN_PID") != str(os.getpid())
        or os.environ.get("LISTEN_FDS") != "1"
    ):
        raise RuntimeError("Expected exactly one systemd listening socket")
    listener = socket.socket(fileno=3)
    if listener.family != socket.AF_INET or not listener.getsockopt(
        socket.SOL_SOCKET, socket.SO_ACCEPTCONN
    ):
        raise RuntimeError("Expected an IPv4 TCP listener")
    return listener


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--address", required=True)
    parser.add_argument("--adapter", default="hci0")
    parser.add_argument("--port", type=int, default=8858)
    parser.add_argument(
        "--listen-address", choices=["127.0.0.1", "0.0.0.0"], default="127.0.0.1"
    )
    parser.add_argument("--state-dir", default="/var/lib/cat-printer")
    parser.add_argument("--socket-activation", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    history = History(Path(args.state_dir) / "jobs.sqlite3")
    service = Service(Transport(args.address, args.adapter), history)
    # The NixOS service inherits its listener without permission to create IP sockets.
    listener = (
        {"sock": inherited_socket()}
        if args.socket_activation
        else {"host": args.listen_address, "port": args.port}
    )
    web.run_app(
        create_app(service, Renderer()),
        **listener,
        access_log=None,
        shutdown_timeout=10,
    )
