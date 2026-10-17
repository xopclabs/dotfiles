"""HTTP API: POST /v1/jobs or /v1/jobs/image; POST /v1/preview[/image].

Markdown requests: {"markdown":"# Hello", "options":{"rotation":0}}.
Rotation defaults to 0 for text and images; use 180 explicitly to flip.
Images: raw PNG/JPEG/WebP body; rendering options are query parameters.
GET /v1/status, GET /v1/jobs[/id], DELETE /v1/jobs/id.
POST /v1/maintenance: {"enabled":true}. No endpoints fetch remote content.
"""

import argparse
import asyncio
import json
import logging
from pathlib import Path

from aiohttp import web
from .protocol import Transport
from .render import InvalidContent, Options, Renderer, png
from .service import History, Rejected, Service

SERVICE = web.AppKey("service", Service)
RENDERER = web.AppKey("renderer", Renderer)
RENDER_SLOTS = web.AppKey("render_slots", asyncio.Semaphore)


@web.middleware
async def safety(request, handler):
    # No browser UI in v1. Reject browser-origin mutations, including simple
    # cross-site forms, rather than trusting CORS to prevent paper-wasting CSRF.
    if request.method not in ("GET", "HEAD"):
        if request.headers.get("Origin") or request.headers.get("Sec-Fetch-Site") in (
            "cross-site",
            "same-site",
        ):
            return web.json_response(
                {"error": "Browser-origin mutations are disabled"}, status=403
            )
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
    client = request.headers.get("X-Printer-Client", "app")
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
            "X-Paper-Length-MM": str(round((image.height + 148) / 8, 1)),
        },
    )


async def status(request):
    return web.json_response(request.app[SERVICE].status())


async def health(request):
    return web.json_response({"alive": True})


async def jobs(request):
    return web.json_response(request.app[SERVICE].history.list())


async def job(request):
    result = request.app[SERVICE].history.get(request.match_info["id"])
    if result is None:
        raise web.HTTPNotFound()
    return web.json_response(result)


async def cancel(request):
    return web.json_response(request.app[SERVICE].cancel(request.match_info["id"]))


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--address", required=True)
    parser.add_argument("--adapter", default="hci0")
    parser.add_argument("--port", type=int, default=8858)
    parser.add_argument(
        "--listen-address", choices=["127.0.0.1", "0.0.0.0"], default="127.0.0.1"
    )
    parser.add_argument("--state-dir", default="/var/lib/cat-printer")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    history = History(Path(args.state_dir) / "jobs.sqlite3")
    service = Service(Transport(args.address, args.adapter), history)
    # Direct LAN access is opt-in and must be source-filtered by the host.
    web.run_app(
        create_app(service, Renderer()),
        host=args.listen_address,
        port=args.port,
        access_log=None,
        shutdown_timeout=10,
    )
