"""Public-print footer; private rendering does not load the barcode encoder."""

import os
import threading

import regex
from PIL import Image, ImageDraw, ImageOps

from .render import CONTENT_ROWS, WIDTH, InvalidContent, font


def with_job_barcode(image, job_id, client_ip=None, timestamp=None):
    """Append a machine-readable footer last on the physical paper feed."""
    from pylibdmtx.pylibdmtx import encode as encode_datamatrix

    if not regex.fullmatch(r"[0-9]{20}", job_id):
        raise InvalidContent("Expected a 20-digit barcode job ID")
    encoded = encode_datamatrix(job_id.encode("ascii"), scheme="Ascii", size="12x26")
    symbol = Image.frombytes(
        "RGB", (encoded.width, encoded.height), encoded.pixels
    ).convert("L")
    # Strip encoder margin; use square four-dot modules and a one-module quiet zone.
    bounds = ImageOps.invert(symbol).getbbox()
    if bounds is None:
        raise InvalidContent("Empty job Data Matrix")
    symbol = symbol.crop(bounds)
    if symbol.width * 12 != symbol.height * 26:
        raise InvalidContent("Unexpected job Data Matrix dimensions")
    symbol = symbol.resize((104, 48), Image.Resampling.NEAREST).convert("1")
    quiet = 4
    footer_rows = symbol.height + 2 * quiet
    if image.height + footer_rows > CONTENT_ROWS:
        raise InvalidContent("Job exceeds 50 cm including barcode and feed")
    result = Image.new("1", (WIDTH, image.height + footer_rows), 1)
    result.paste(image, (0, 0))
    symbol_x = WIDTH - quiet - symbol.width
    result.paste(symbol, (symbol_x, image.height + quiet))
    if client_ip is not None and timestamp is not None:
        font_path = os.path.join(os.environ["CATPRINTER_FONT_DIR"], "DejaVuSans.ttf")
        text_width = symbol_x - quiet - 8
        text = Image.new("L", (symbol_x - quiet, footer_rows), 255)
        draw = ImageDraw.Draw(text)
        for value, y in ((client_ip, 8), (timestamp, 30)):
            size = 16
            f = font(font_path, size, threading.get_ident())
            while f.getlength(value) > text_width and size > 8:
                size -= 1
                f = font(font_path, size, threading.get_ident())
            if f.getlength(value) > text_width:
                raise InvalidContent("Footer text exceeds available width")
            draw.text((8, y), value, font=f, fill=0, anchor="lt")
        text = text.point(lambda p: 255 if p >= 160 else 0).convert("1")
        result.paste(text, (0, image.height))
    return result
