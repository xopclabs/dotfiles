import io
import os
import threading
from dataclasses import dataclass
from functools import lru_cache

import regex
from fontTools.ttLib import TTFont
from markdown_it import MarkdownIt
from PIL import Image, ImageDraw, ImageFont, ImageOps

WIDTH = 384
MAX_ROWS = 4000  # 50 cm at 8 dots/mm, including trailing feed.
CONTENT_ROWS = MAX_ROWS - 100
# Enforce the public upload limit explicitly; private uploads may be larger.
Image.MAX_IMAGE_PIXELS = None
PUBLIC_IMAGE_PIXELS = 16_000_000


class InvalidContent(ValueError):
    pass


@dataclass(frozen=True)
class Options:
    rotation: int = 0
    font_size: int = 24
    dither: str = "floyd-steinberg"
    align: str = "left"

    @classmethod
    def parse(cls, values):
        if (
            not isinstance(values, dict)
            or values.keys() - cls.__dataclass_fields__.keys()
        ):
            raise InvalidContent("Unknown rendering options")
        result = cls(**values)
        if type(result.rotation) is not int or result.rotation not in (0, 180):
            raise InvalidContent("rotation must be 0 or 180")
        if type(result.font_size) is not int or not 16 <= result.font_size <= 40:
            raise InvalidContent("font_size must be between 16 and 40")
        if result.dither not in (
            "floyd-steinberg",
            "threshold",
        ) or result.align not in ("left", "center", "right"):
            raise InvalidContent("Invalid dither or alignment")
        return result


@lru_cache(maxsize=16)
def coverage(path):
    with TTFont(path) as font:
        return frozenset(font.getBestCmap())


@lru_cache(maxsize=128)
def font(path, size, _thread_id):
    return ImageFont.truetype(path, size)


class Renderer:
    def __init__(self, font_dir=None, emoji=None):
        self.font_dir = font_dir or os.environ["CATPRINTER_FONT_DIR"]
        self.emoji = emoji or os.environ["CATPRINTER_EMOJI_FONT"]

    def glyph(self, text, size, style):
        name = {
            "normal": "DejaVuSans.ttf",
            "bold": "DejaVuSans-Bold.ttf",
            "italic": "DejaVuSans-Oblique.ttf",
            "code": "DejaVuSansMono.ttf",
        }[style]
        path = os.path.join(self.font_dir, name)
        points = {ord(c) for c in text if ord(c) not in (0xFE0F, 0xFE0E, 0x200D)}
        if not points <= coverage(path):
            if points <= coverage(self.emoji):
                path = self.emoji
                # Use monochrome presentation, not color bitmap strikes.
                text = text.replace("\ufe0f", "")
            else:
                text = "□"
        f = font(path, size, threading.get_ident())
        return text, f, f.getlength(text)

    def finish(self, image, options):
        if image.height > CONTENT_ROWS:
            raise InvalidContent(
                "Job exceeds 50 cm including feed; split it explicitly"
            )
        image = (
            image.transpose(Image.Transpose.ROTATE_180) if options.rotation else image
        )
        return image.convert("1", dither=Image.Dither.NONE)

    def image(self, raw, options, *, max_pixels=None):
        try:
            with Image.open(io.BytesIO(raw)) as source:
                if (
                    source.format not in ("PNG", "JPEG", "WEBP")
                    or getattr(source, "n_frames", 1) != 1
                ):
                    raise InvalidContent("Upload a single PNG, JPEG, or WebP image")
                if max_pixels is not None and source.width * source.height > max_pixels:
                    raise InvalidContent("Image exceeds 16 megapixels")
                source.load()
                image = ImageOps.exif_transpose(source).convert("RGBA")
            background = Image.new("RGBA", image.size, "white")
            background.alpha_composite(image)
            height = max(1, round(image.height * WIDTH / image.width))
            if height > CONTENT_ROWS:
                raise InvalidContent("Job exceeds 50 cm including feed")
            image = background.convert("L").resize(
                (WIDTH, height), Image.Resampling.LANCZOS
            )
        except (
            OSError,
            Image.DecompressionBombError,
            Image.DecompressionBombWarning,
        ) as exc:
            raise InvalidContent("Invalid or oversized image") from exc
        if options.dither == "threshold":
            image = image.point(lambda p: 255 if p >= 128 else 0).convert("1")
        else:
            image = image.convert("1", dither=Image.Dither.FLOYDSTEINBERG)
        return self.finish(image, options)

    def markdown(self, text, options):
        if not isinstance(text, str) or not text.strip() or len(text) > 32000:
            raise InvalidContent("markdown must contain 1–32000 characters")
        parser = MarkdownIt("commonmark", {"html": True}).enable("table")
        tokens = parser.parse(text)
        image = Image.new("L", (WIDTH, CONTENT_ROWS), "white")
        draw = ImageDraw.Draw(image)
        y, indent = 8, 0
        size = options.font_size
        heading = False
        list_stack = []

        def line(runs, prefix=""):
            nonlocal y
            left, right = 8 + indent, WIDTH - 8
            glyphs = []
            if prefix:
                runs = [(prefix, "normal")] + runs
            for value, style in runs:
                for cluster in regex.findall(r"\X", value):
                    glyphs.append((*self.glyph(cluster, size, style), cluster))
            # Wrap at whitespace when possible; long words/code still wrap.
            pending, width = [], 0

            def flush(items):
                nonlocal y
                if y + size + 10 > CONTENT_ROWS:
                    raise InvalidContent("Job exceeds 50 cm including feed")
                measured = sum(g[2] for g in items)
                x = left
                if options.align == "center":
                    x += max(0, (right - left - measured) / 2)
                elif options.align == "right":
                    x += max(0, right - left - measured)
                for value, f, advance, _ in items:
                    draw.text((x, y + size), value, fill=0, font=f, anchor="ls")
                    x += advance
                y += size + 7

            for glyph in glyphs:
                if glyph[3] == "\n":
                    flush(pending)
                    pending, width = [], 0
                    continue
                if width + glyph[2] > right - left and pending:
                    split = next(
                        (
                            i
                            for i in range(len(pending) - 1, -1, -1)
                            if pending[i][3].isspace()
                        ),
                        -1,
                    )
                    if split > 0:
                        flush(pending[:split])
                        pending = pending[split + 1 :]
                        width = sum(g[2] for g in pending)
                    if width + glyph[2] > right - left:
                        flush(pending)
                        pending, width = [], 0
                pending.append(glyph)
                width += glyph[2]
            if pending or not glyphs:
                flush(pending)

        def inline(token):
            runs, stack, links = [], ["bold" if heading else "normal"], []
            for child in token.children or []:
                kind = child.type
                if kind in ("image", "html_inline"):
                    raise InvalidContent("HTML and embedded images are not supported")
                if kind in ("strong_open", "em_open"):
                    stack.append("bold" if kind == "strong_open" else "italic")
                elif kind in ("strong_close", "em_close"):
                    stack.pop()
                elif kind == "code_inline":
                    runs.append((child.content, "code"))
                elif kind == "link_open":
                    links.append(child.attrGet("href") or "")
                elif kind == "link_close":
                    url = links.pop()
                    if url:
                        runs.append((f" ({url})", "normal"))
                elif kind in ("softbreak", "hardbreak"):
                    runs.append((" " if kind == "softbreak" else "\n", stack[-1]))
                elif kind == "text":
                    runs.append((child.content, stack[-1]))
            return runs

        i = 0
        while i < len(tokens):
            token = tokens[i]
            kind = token.type
            if kind == "html_block":
                raise InvalidContent("HTML is not supported")
            if kind == "table_open":
                headers, rows, row, cell, in_header = [], [], [], None, False
                i += 1
                while tokens[i].type != "table_close":
                    t = tokens[i]
                    if t.type == "thead_open":
                        in_header = True
                    elif t.type == "thead_close":
                        in_header = False
                    elif t.type == "tr_open":
                        row = []
                    elif t.type == "inline":
                        cell = inline(t)
                        row.append(cell)
                    elif t.type == "tr_close":
                        if in_header:
                            headers = row
                        else:
                            rows.append(row)
                    i += 1
                for row in rows:
                    for n, cell in enumerate(row):
                        label = (
                            headers[n]
                            if n < len(headers)
                            else [(f"Column {n + 1}", "bold")]
                        )
                        line(
                            [(s, "bold") for s, _ in label] + [(": ", "normal")] + cell
                        )
                    y += 8
            elif kind == "heading_open":
                size = min(40, options.font_size + (8 if token.tag == "h1" else 4))
                heading = True
            elif kind == "heading_close":
                size, heading = options.font_size, False
                y += 6
            elif kind in ("bullet_list_open", "ordered_list_open"):
                list_stack.append(
                    [kind == "ordered_list_open", int(token.attrGet("start") or 1)]
                )
            elif kind in ("bullet_list_close", "ordered_list_close"):
                list_stack.pop()
            elif kind == "list_item_open":
                indent = min(64, len(list_stack) * 12)
            elif kind == "list_item_close":
                indent = min(64, max(0, len(list_stack) - 1) * 12)
            elif kind == "inline":
                prefix = ""
                if list_stack and i and tokens[i - 1].type == "paragraph_open":
                    ordered, number = list_stack[-1]
                    prefix = f"{number}. " if ordered else "• "
                    list_stack[-1][1] += 1
                line(inline(token), prefix)
            elif kind in ("fence", "code_block"):
                old_size, size = size, max(16, options.font_size - 4)
                for value in token.content.rstrip("\n").split("\n"):
                    line([(value, "code")])
                size = old_size
            elif kind == "paragraph_close":
                y += 6
            elif kind == "hr":
                if y + 8 > CONTENT_ROWS:
                    raise InvalidContent("Job exceeds 50 cm including feed")
                draw.line((8, y + 3, WIDTH - 8, y + 3), fill=0)
                y += 12
            i += 1
        if y + 8 > CONTENT_ROWS:
            raise InvalidContent("Job exceeds 50 cm including feed")
        image = image.crop((0, 0, WIDTH, max(1, y + 8)))
        image = image.point(lambda p: 255 if p >= 160 else 0)
        return self.finish(image, options)


def png(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()
