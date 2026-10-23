"""Small HTTP client for the single-owner cat printer service."""

import argparse
import http.client
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

MAX_BODY = 8 * 1024 * 1024
MAX_TEXT = 32_000
ACTIVE = {"queued", "preparing", "printing"}
TERMINAL = {"finished", "sent", "uncertain", "failed", "cancelled", "expired"}


class ClientError(Exception):
    pass


class TransportError(ClientError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward printed content to a different endpoint or replay POSTs.
        return None


def endpoint(value):
    if not value or any(ord(char) < 33 or ord(char) > 126 for char in value):
        raise ClientError(
            "API URL must be an ASCII URL without whitespace/control characters"
        )
    try:
        parsed = urllib.parse.urlsplit(value)
        port = parsed.port
    except ValueError as exc:
        raise ClientError("Invalid API URL") from exc
    if (
        parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or (port is not None and port == 0)
    ):
        raise ClientError(
            "API URL must be HTTP(S), without credentials, query or fragment"
        )
    return value.rstrip("/")


def edit_input(plain=False):
    editor = os.environ.get("VISUAL") or os.environ.get("EDITOR") or "vim"
    try:
        command = shlex.split(editor)
    except ValueError as exc:
        raise ClientError("Invalid VISUAL/EDITOR command") from exc
    if not command:
        raise ClientError("VISUAL/EDITOR command is empty")
    with tempfile.TemporaryDirectory(prefix="catprint-") as directory:
        path = os.path.join(directory, "print.txt" if plain else "print.md")
        with open(path, "xb"):
            pass
        # Editor UI goes to the controlling terminal, never the job-ID stdout.
        with open("/dev/tty", "r+b", buffering=0) as terminal:
            result = subprocess.run(
                [*command, path],
                stdin=terminal,
                stdout=terminal,
                stderr=terminal,
                check=False,
            )
        if result.returncode != 0:
            raise ClientError("Editor exited unsuccessfully; nothing queued")
        with open(path, "rb") as source:
            raw = source.read(MAX_BODY + 1)
    if not raw or not raw.decode("utf-8-sig", errors="replace").strip():
        return None
    return raw


def read_input(args, stdin):
    if args.text is not None:
        if args.file is not None:
            raise ClientError("Use text, --file, or stdin, not multiple input sources")
        raw = args.text.encode("utf-8")
    elif args.file not in (None, "-"):
        with open(args.file, "rb") as source:
            raw = source.read(MAX_BODY + 1)
    elif args.file is None and stdin.isatty():
        raw = edit_input(args.plain)
        if raw is None:
            return None
    else:
        if stdin.isatty():
            raise ClientError("--file - requires piped stdin")
        raw = stdin.buffer.read(MAX_BODY + 1)
    if not raw:
        raise ClientError("Input is empty")
    if len(raw) > MAX_BODY:
        raise ClientError("Input exceeds 8 MiB")
    return raw


def encode_input(raw, plain=False, rotation=0):
    mime = None
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        mime = "image/png"
    elif raw.startswith(b"\xff\xd8\xff"):
        mime = "image/jpeg"
    elif raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        mime = "image/webp"
    if mime:
        if plain:
            raise ClientError("--plain is only for text")
        return f"/v1/jobs/image?rotation={rotation}", mime, raw
    if not plain and raw.startswith((b"%PDF-", b"GIF87a", b"GIF89a")):
        raise ClientError(
            "Unsupported document/image format; use UTF-8 text or PNG/JPEG/WebP"
        )
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ClientError(
            "Input must be UTF-8 text or a PNG, JPEG, or WebP image"
        ) from exc
    if any(ord(char) < 32 and char not in "\t\r\n" for char in text):
        raise ClientError(
            "Input contains binary/control bytes; expected text or PNG/JPEG/WebP"
        )
    if not text.strip():
        raise ClientError("Input is empty")
    if len(text) > MAX_TEXT:
        raise ClientError("Text exceeds 32,000 characters")
    if plain:
        # A fence longer than every input run cannot be closed by the input.
        fence = "`" * max(
            3, max((len(s) + 1 for s in re.findall(r"`+", text)), default=3)
        )
        text = fence + "\n" + text + ("" if text.endswith("\n") else "\n") + fence
        if len(text) > MAX_TEXT:
            raise ClientError(
                "Plain text plus literal-text framing exceeds 32,000 characters"
            )
    body = json.dumps(
        {"markdown": text, "options": {"rotation": rotation}}, ensure_ascii=False
    ).encode("utf-8")
    return "/v1/jobs", "application/json", body


class API:
    def __init__(self, url):
        self.url = endpoint(url)
        # Ignore ambient proxies for the private LAN service and never follow redirects.
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), NoRedirect()
        )

    def request(self, path, *, body=None, headers=None, timeout=15):
        req = urllib.request.Request(self.url + path, data=body, headers=headers or {})
        try:
            with self.opener.open(req, timeout=timeout) as response:
                raw = response.read(64 * 1024 + 1)
                if len(raw) > 64 * 1024:
                    raise ClientError("API response is too large")
                result = json.loads(raw)
        except urllib.error.HTTPError as exc:
            hints = {
                400: "Invalid content/options",
                403: "Request forbidden",
                409: "Request conflicts with printer state",
                413: "Input too large",
                415: "Unsupported image/content type",
                429: "Printer queue or renderer busy",
                503: "Printer unavailable; no job was queued",
            }
            # Do not echo arbitrary server bodies (they may contain user content).
            code = exc.code
            exc.close()
            raise ClientError(
                f"HTTP {code}: {hints.get(code, 'API request rejected')}"
            ) from exc
        except (
            urllib.error.URLError,
            OSError,
            TimeoutError,
            http.client.HTTPException,
        ) as exc:
            raise TransportError("API connection failed or timed out") from exc
        except (ValueError, UnicodeError) as exc:
            raise ClientError("API returned invalid JSON") from exc
        if not isinstance(result, dict):
            raise ClientError("API returned an invalid job record")
        return result


def validate_job(job, expected_id=None):
    job_id = job.get("id")
    try:
        valid_id = isinstance(job_id, str) and str(uuid.UUID(job_id)) == job_id
    except ValueError:
        valid_id = False
    if not valid_id or job.get("state") not in ACTIVE | TERMINAL:
        raise ClientError("API returned an invalid job record")
    if expected_id is not None and job_id != expected_id:
        raise ClientError("API returned a different job ID")
    return job_id


def wait_for_job(api, job, seconds, stderr):
    job_id = validate_job(job)
    deadline = time.monotonic() + seconds
    while job["state"] in ACTIVE:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            print(
                f"catprint: wait timed out; job {job_id} may still print. Do not resubmit.",
                file=stderr,
            )
            return 5
        time.sleep(min(1, remaining))
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            continue
        job = api.request("/v1/jobs/" + job_id, timeout=min(15, remaining))
        validate_job(job, job_id)
    state = job["state"]
    if state == "finished":
        print("Printer reported idle", file=stderr)
        return 0
    if state == "sent":
        print(
            "catprint: data sent; printer idle was not confirmed. Do not automatically reprint.",
            file=stderr,
        )
        return 3
    if state == "uncertain":
        print(
            "catprint: print outcome uncertain; inspect the paper before reprinting.",
            file=stderr,
        )
        return 4
    print(f"catprint: job {state}", file=stderr)
    return 1


def parser():
    result = argparse.ArgumentParser(
        description="Enqueue text or PNG/JPEG/WebP on the cat printer HTTP API.",
        epilog="Bare catprint opens VISUAL/EDITOR (fallback: vim). Save and exit to submit; "
        "nonzero editor exit or an empty buffer submits nothing. "
        "Examples: catprint 'Hello **world**'; wl-paste --type image/png | catprint; "
        "wl-paste --type text | catprint --plain. stdout contains only the job ID.",
    )
    result.add_argument(
        "text",
        nargs="?",
        help="quoted Markdown text (otherwise pipe input or open an editor)",
    )
    result.add_argument(
        "-f", "--file", help="text/image file, or - for stdin; detect type from bytes"
    )
    result.add_argument(
        "--plain", action="store_true", help="render text literally instead of Markdown"
    )
    result.add_argument(
        "--rotation",
        type=int,
        choices=(0, 180),
        default=180,
        help="rotate text/images by this many degrees (default: 180, reversed feed)",
    )
    result.add_argument(
        "--url",
        default=os.environ.get("CATPRINTER_URL"),
        help="API base URL (default: CATPRINTER_URL)",
    )
    result.add_argument(
        "--wait",
        action="store_true",
        help="wait for API outcome, not physical-print confirmation",
    )
    result.add_argument(
        "--wait-timeout",
        type=int,
        default=300,
        metavar="SECONDS",
        help="maximum --wait duration (default: 300)",
    )
    result.add_argument(
        "--idempotency-key",
        help="reuse only to recover the SAME submission after a lost response",
    )
    return result


def main(argv=None, stdin=None, stdout=None, stderr=None):
    stdin = sys.stdin if stdin is None else stdin
    stdout = sys.stdout if stdout is None else stdout
    stderr = sys.stderr if stderr is None else stderr
    args = parser().parse_args(argv)
    key = args.idempotency_key or str(uuid.uuid4())
    submitted = False
    job_id = None
    try:
        if not args.url:
            raise ClientError("Set CATPRINTER_URL or use --url")
        if args.wait_timeout <= 0:
            raise ClientError("--wait-timeout must be positive")
        if (
            not 1 <= len(key) <= 128
            or not key.isascii()
            or any(ord(c) < 33 or ord(c) > 126 for c in key)
        ):
            raise ClientError(
                "Idempotency key must be 1–128 printable ASCII characters without spaces"
            )
        api = API(args.url)
        raw = read_input(args, stdin)
        if raw is None:
            print("catprint: empty buffer; nothing queued.", file=stderr)
            return 0
        path, mime, body = encode_input(raw, args.plain, args.rotation)
        submitted = True
        job = api.request(
            path,
            body=body,
            headers={
                "Content-Type": mime,
                "X-Printer-Client": "catprint",
                "Idempotency-Key": key,
            },
        )
        job_id = validate_job(job)
        print(job_id, file=stdout, flush=True)
        if args.wait:
            return wait_for_job(api, job, args.wait_timeout, stderr)
        if job["state"] not in ACTIVE | {"finished"}:
            # An explicitly reused key may refer to an older failed/uncertain job.
            return wait_for_job(api, job, args.wait_timeout, stderr)
        return 0
    except (ClientError, OSError, UnicodeError) as exc:
        print(f"catprint: {exc}", file=stderr)
        if submitted:
            if job_id:
                print(
                    f"catprint: job {job_id} may still print; do not resubmit.",
                    file=stderr,
                )
            else:
                print(
                    f"catprint: no automatic retry. If submission is unclear, reuse --idempotency-key {key} for this same job only.",
                    file=stderr,
                )
        return 1
    except KeyboardInterrupt:
        if not submitted:
            print("catprint: interrupted; nothing queued.", file=stderr)
            return 130
        print("catprint: interrupted; an accepted job is NOT cancelled.", file=stderr)
        if submitted and job_id is None:
            print(
                f"catprint: recover this same submission with --idempotency-key {key}; do not use a new key.",
                file=stderr,
            )
        return 130


if __name__ == "__main__":
    sys.exit(main())
