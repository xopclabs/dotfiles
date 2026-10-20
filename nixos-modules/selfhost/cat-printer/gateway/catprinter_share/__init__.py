"""Temporary, fixed-destination public gateway for the printer web UI."""

import argparse
import asyncio
import ipaddress
import logging
import time

from aiohttp import ClientError, ClientSession, ClientTimeout, UnixConnector, web

LIMIT = 8 * 1024 * 1024
GET_PATHS = frozenset(
    (
        "/",
        "/sw.js",
        "/ui/static/manifest.webmanifest",
        "/ui/static/icon.png",
        "/ui/static/icon-512.png",
        "/ui/static/app.js",
        "/ui/static/style.css",
        "/ui/api/status",
    )
)
POST_PATHS = frozenset(
    (
        "/ui/api/preview",
        "/ui/api/preview/image",
        "/ui/api/jobs",
        "/ui/api/jobs/image",
    )
)
REQUEST_HEADERS = (
    "Content-Type",
    "Origin",
    "Sec-Fetch-Site",
    "X-Browser-Identity",
    "Idempotency-Key",
)
RESPONSE_HEADERS = (
    "Content-Type",
    "X-Print-Rows",
    "X-Paper-Length-MM",
    "Content-Security-Policy",
    "X-Content-Type-Options",
    "Referrer-Policy",
)


def create_app(printer_socket, expires_at, trusted_proxy, clock=time.time):
    proxy = ipaddress.ip_address(trusted_proxy)
    session_key = web.AppKey("upstream", ClientSession)

    @web.middleware
    async def access(request, handler):
        peer = ipaddress.ip_address(request.remote)
        if peer != proxy:
            raise web.HTTPForbidden(text="Untrusted proxy")
        client = peer
        # Traefik appends the connecting client after any untrusted values.
        forwarded = request.headers.get("X-Forwarded-For", "").split(",")[-1].strip()
        if forwarded:
            try:
                client = ipaddress.ip_address(forwarded)
            except ValueError:
                raise web.HTTPBadRequest(text="Invalid forwarded client IP")
        request["client_ip"] = str(client)
        status = 500
        try:
            response = await handler(request)
            status = response.status
            return response
        except web.HTTPException as exc:
            status = exc.status
            raise
        finally:
            # Never log query strings, arbitrary paths, or request payloads.
            path = (
                request.path if request.path in GET_PATHS | POST_PATHS else "[rejected]"
            )
            logging.getLogger(__name__).info(
                "client_ip=%s method=%s path=%s status=%s",
                client,
                request.method,
                path,
                status,
            )

    @web.middleware
    async def gate(request, handler):
        if clock() >= expires_at:
            return web.json_response(
                {"error": "Printer sharing has expired"},
                status=410,
                headers={
                    "Cache-Control": "no-store",
                    "X-Content-Type-Options": "nosniff",
                },
            )
        paths = (
            GET_PATHS
            if request.method in ("GET", "HEAD")
            else POST_PATHS if request.method == "POST" else ()
        )
        if (
            request.path not in paths
            or request.raw_path.split("?", 1)[0] != request.path
        ):
            raise web.HTTPNotFound()
        try:
            response = await handler(request)
        except (ClientError, TimeoutError):
            response = web.json_response({"error": "Printer unavailable"}, status=502)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    async def forward(request):
        async with asyncio.timeout(15):
            body = await request.read()
        if clock() >= expires_at:
            return web.json_response(
                {"error": "Printer sharing has expired"}, status=410
            )
        headers = {
            key: request.headers[key]
            for key in REQUEST_HEADERS
            if key in request.headers
        }
        headers["X-Catprinter-Client-IP"] = request["client_ip"]
        headers["Host"] = request.host
        headers["Accept-Encoding"] = "identity"
        async with request.app[session_key].request(
            request.method,
            "http://localhost" + request.path,
            params=request.query,
            data=body,
            headers=headers,
            allow_redirects=False,
        ) as result:
            if 300 <= result.status < 400:
                return web.json_response(
                    {"error": "Unexpected printer redirect"}, status=502
                )
            content = bytearray()
            async for chunk in result.content.iter_chunked(65536):
                content.extend(chunk)
                if len(content) > LIMIT:
                    return web.json_response(
                        {"error": "Printer response too large"}, status=502
                    )
            return web.Response(
                status=result.status,
                body=bytes(content),
                headers={
                    key: result.headers[key]
                    for key in RESPONSE_HEADERS
                    if key in result.headers
                },
            )

    async def session(app):
        async with ClientSession(
            connector=UnixConnector(path=printer_socket),
            timeout=ClientTimeout(total=30, connect=5),
            trust_env=False,
            auto_decompress=False,
        ) as client:
            app[session_key] = client
            yield

    app = web.Application(middlewares=[access, gate], client_max_size=LIMIT)
    app.cleanup_ctx.append(session)
    app.router.add_route("*", "/{path:.*}", forward)
    return app


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen-address", type=ipaddress.IPv4Address, required=True)
    parser.add_argument("--port", type=int, default=18858)
    parser.add_argument("--printer-socket", required=True)
    parser.add_argument("--expires-at", type=int, required=True)
    parser.add_argument("--trusted-proxy", type=ipaddress.IPv4Address, required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    web.run_app(
        create_app(
            args.printer_socket,
            args.expires_at,
            trusted_proxy=str(args.trusted_proxy),
        ),
        host=str(args.listen_address),
        port=args.port,
        access_log=None,
    )
