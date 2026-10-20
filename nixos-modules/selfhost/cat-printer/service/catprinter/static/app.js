"use strict";
const $ = (id) => document.getElementById(id);
const storageKey = "catprinter-v1";
const randomToken = () =>
  Array.from(crypto.getRandomValues(new Uint8Array(32)), (x) =>
    x.toString(16).padStart(2, "0"),
  ).join("");
let saved = {};
try {
  saved = JSON.parse(localStorage.getItem(storageKey) || "{}") || {};
} catch {}
let identity = /^[a-f0-9]{64}$/.test(saved.identity)
  ? saved.identity
  : randomToken();
let mode = "markdown",
  bitmap = null,
  rotation = Number(saved.rotation) || 0;
let revision = 0,
  readyRevision = -1,
  prepared = null,
  timer,
  controller,
  previewUrl,
  originalUrl;
let available = false,
  submitting = false,
  imageGeneration = 0;
const fields = [
  "markdown",
  "font",
  "align",
  "flip",
  "dither",
  "black",
  "threshold",
];
for (const id of fields) {
  if (saved[id] !== undefined) {
    if (id === "flip") $(id).checked = !!saved[id];
    else $(id).value = saved[id];
  }
}
function boundedFont(value) {
  const size = Number(value);
  return value !== "" && Number.isInteger(size)
    ? Math.min(40, Math.max(16, size))
    : 24;
}
$("font").value = boundedFont($("font").value);
function commitFont() {
  const value = String(boundedFont($("font").value));
  if ($("font").value !== value) {
    $("font").value = value;
    changed();
  }
}
function indicator(id, tone, text) {
  const icons = {
    success: "check",
    error: "warning",
    busy: "loader",
    offline: "offline",
  };
  $(id).hidden = !text;
  $(id).dataset.tone = tone;
  $(id + "-icon").setAttribute("href", "#i-" + icons[tone]);
  $(id + "-text").textContent = text;
  $(id).setAttribute("aria-label", text);
  $(id).title = text;
}
function notice(tone = "success", text = "") {
  indicator("message", tone, text);
}
function persist() {
  const value = { identity, rotation };
  for (const id of fields)
    value[id] = id === "flip" ? $(id).checked : $(id).value;
  value.font = String(boundedFont(value.font));
  try {
    localStorage.setItem(storageKey, JSON.stringify(value));
  } catch {
    notice(
      "error",
      "Browser storage unavailable; this session may not survive refresh.",
    );
  }
}
persist();
async function api(path, options = {}) {
  const response = await fetch("/ui/api/" + path, {
    signal: AbortSignal.timeout(30000),
    ...options,
    headers: { ...options.headers, "X-Browser-Identity": identity },
    cache: "no-store",
  });
  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      message = (await response.json()).error || message;
    } catch {}
    throw new Error(message);
  }
  return response;
}
function printState() {
  $("print").disabled =
    !available || submitting || readyRevision !== revision || !prepared;
}
function changed() {
  revision++;
  readyRevision = -1;
  prepared = null;
  controller?.abort();
  clearTimeout(timer);
  $("preview").classList.add("stale");
  $("length").textContent = "";
  notice();
  const fontSize = Number($("font").value);
  $("font-up").disabled = fontSize >= 40;
  $("font-down").disabled = fontSize <= 16;
  $("align-icon").setAttribute("href", "#i-align-" + $("align").value);
  $("black-value").textContent = $("black").value;
  $("threshold-value").textContent = $("threshold").value;
  $("threshold-label").hidden = $("dither").value !== "threshold";
  printState();
  persist();
  timer = setTimeout(updatePreview, 350);
}
$("font").addEventListener("blur", commitFont);
$("font").addEventListener("keydown", (event) => {
  if (event.key === "Enter") commitFont();
  if (
    !event.ctrlKey &&
    !event.metaKey &&
    !event.altKey &&
    event.key.length === 1 &&
    /\D/.test(event.key)
  )
    event.preventDefault();
});
for (const id of fields)
  $(id).addEventListener("input", () => {
    if (id === "font") $(id).value = $(id).value.replace(/\D/g, "").slice(0, 2);
    changed();
  });
for (const [id, step] of [
  ["font-up", 1],
  ["font-down", -1],
]) {
  $(id).onclick = () => {
    const current = Number($("font").value) || 24;
    $("font").value = Math.min(40, Math.max(16, current + step));
    changed();
  };
}
function selectTab(next) {
  mode = next;
  for (const tab of ["markdown", "image"]) {
    $(tab + "-tab").setAttribute("aria-selected", String(tab === mode));
    $(tab + "-panel").hidden = tab !== mode;
    $(tab + "-tab").tabIndex = tab === mode ? 0 : -1;
  }
  changed();
}
for (const tab of ["markdown", "image"]) {
  $(tab + "-tab").onclick = () => selectTab(tab);
  $(tab + "-tab").onkeydown = (event) => {
    if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
      event.preventDefault();
      selectTab(
        event.key === "Home"
          ? "markdown"
          : event.key === "End"
            ? "image"
            : mode === "markdown"
              ? "image"
              : "markdown",
      );
      $(mode + "-tab").focus();
    }
  };
}
for (const [id, degrees] of [
  ["rotate", 90],
  ["rotate-left", -90],
]) {
  $(id).onclick = () => {
    rotation = (rotation + degrees + 360) % 360;
    changed();
  };
}
async function loadImage(files) {
  files = [...files];
  if (!files.length) return;
  const generation = ++imageGeneration;
  bitmap?.close();
  bitmap = null;
  if (originalUrl) URL.revokeObjectURL(originalUrl);
  $("original").hidden = true;
  $("upload-prompt").hidden = false;
  changed();
  try {
    const strip = document.createElement("canvas");
    strip.width = 384;
    const parts = [];
    let height = 0;
    try {
      for (const file of files) {
        if (!["image/png", "image/jpeg", "image/webp"].includes(file.type))
          throw new Error("Choose PNG, JPEG or WebP images.");
        const part = await createImageBitmap(file);
        parts.push(part);
        if (part.width * part.height > 16000000)
          throw new Error("Image exceeds 16 megapixels.");
        height += Math.max(1, Math.round((part.height * 384) / part.width));
        if (height > 3900)
          throw new Error("Combined images exceed the 50 cm print limit.");
        if (generation !== imageGeneration) return;
      }
      strip.height = height;
      const ctx = strip.getContext("2d");
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, 384, height);
      let y = 0;
      for (const part of parts) {
        const rows = Math.max(1, Math.round((part.height * 384) / part.width));
        ctx.drawImage(part, 0, y, 384, rows);
        y += rows;
      }
    } finally {
      for (const part of parts) part.close();
    }
    const decoded = await createImageBitmap(strip);
    if (generation !== imageGeneration) {
      decoded.close();
      return;
    }
    if (decoded.width * decoded.height > 16000000) {
      decoded.close();
      throw new Error("Image exceeds 16 megapixels.");
    }
    bitmap = decoded;
    const names = files.map((file) => file.name).join(" → ");
    $("filename").textContent = names;
    $("filename").title = names;
    const source = await new Promise((resolve) => strip.toBlob(resolve));
    if (generation !== imageGeneration) return;
    originalUrl = URL.createObjectURL(source);
    $("original").src = originalUrl;
    $("original").hidden = false;
    $("upload-prompt").hidden = true;
    changed();
  } catch (error) {
    if (generation !== imageGeneration) return;
    $("filename").textContent = "";
    $("filename").title = "No image selected";
    notice("error", error.message);
  }
}
$("file").onchange = () => loadImage($("file").files);
for (const event of ["dragenter", "dragover"])
  $("drop").addEventListener(event, (e) => {
    e.preventDefault();
    $("drop").classList.add("drag");
  });
$("drop").ondragleave = () => $("drop").classList.remove("drag");
$("drop").ondrop = (e) => {
  e.preventDefault();
  $("drop").classList.remove("drag");
  loadImage(e.dataTransfer.files);
};
function pastedImage(data) {
  const files = [...data.files];
  if (!files.some((file) => file.type.startsWith("image/"))) {
    for (const item of data.items) {
      if (item.kind !== "file" || !item.type.startsWith("image/")) continue;
      const pasted = item.getAsFile();
      if (!pasted) continue;
      files.push(
        pasted.type
          ? pasted
          : new File([pasted], pasted.name, { type: item.type }),
      );
    }
  }
  return files.filter((item) => item.type.startsWith("image/"));
}
window.addEventListener("paste", (event) => {
  const data = event.clipboardData;
  if (!data) return;
  const files = pastedImage(data);
  if (!files.length) return;
  if (
    mode === "markdown" &&
    event.target === $("markdown") &&
    data.getData("text/plain")
  )
    return;
  event.preventDefault();
  if (mode !== "image") selectTab("image");
  loadImage(files);
});
async function imageBody() {
  const canvas = document.createElement("canvas");
  const sideways = rotation % 180 !== 0;
  canvas.width = sideways ? bitmap.height : bitmap.width;
  canvas.height = sideways ? bitmap.width : bitmap.height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.translate(canvas.width / 2, canvas.height / 2);
  ctx.rotate((rotation * Math.PI) / 180);
  ctx.drawImage(bitmap, -bitmap.width / 2, -bitmap.height / 2);
  const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const black = Number($("black").value);
  const threshold = Number($("threshold").value);
  const plain = $("dither").value === "threshold";
  for (let i = 0; i < pixels.data.length; i += 4) {
    const gray =
      0.299 * pixels.data[i] +
      0.587 * pixels.data[i + 1] +
      0.114 * pixels.data[i + 2];
    let value = Math.max(0, ((gray - black) * 255) / (255 - black));
    // Shift the selected threshold to the renderer's fixed threshold of 128.
    if (plain) value = Math.max(0, Math.min(255, value + 128 - threshold));
    pixels.data[i] =
      pixels.data[i + 1] =
      pixels.data[i + 2] =
        Math.round(value);
  }
  ctx.putImageData(pixels, 0, 0);
  const blob = await new Promise((resolve) =>
    canvas.toBlob(resolve, "image/png"),
  );
  if (!blob || blob.size > 8 * 1024 * 1024)
    throw new Error("Processed image exceeds 8 MiB; choose a smaller image.");
  return blob;
}
async function updatePreview() {
  const current = revision;
  if (
    (mode === "markdown" && !$("markdown").value.trim()) ||
    (mode === "image" && !bitmap)
  ) {
    $("preview").hidden = true;
    $("placeholder").hidden = false;
    return;
  }
  controller = new AbortController();
  const signal = controller.signal;
  notice("busy", "Rendering preview…");
  try {
    let request;
    if (mode === "markdown") {
      if (
        !$("font").checkValidity() ||
        Number($("font").value) < 16 ||
        Number($("font").value) > 40
      )
        throw new Error("Font size must be between 16 and 40.");
      request = {
        suffix: "",
        body: JSON.stringify({
          markdown: $("markdown").value,
          options: {
            font_size: Number($("font").value),
            align: $("align").value,
            rotation: $("flip").checked ? 180 : 0,
          },
        }),
        type: "application/json",
      };
    } else {
      request = {
        suffix: "/image?dither=" + encodeURIComponent($("dither").value),
        body: await imageBody(),
        type: "image/png",
      };
    }
    if (current !== revision || signal.aborted) return;
    const response = await api("preview" + request.suffix, {
      method: "POST",
      body: request.body,
      headers: { "Content-Type": request.type },
      signal,
    });
    const blob = await response.blob();
    if (current !== revision) return;
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    previewUrl = URL.createObjectURL(blob);
    $("preview").src = previewUrl;
    $("preview").hidden = false;
    $("preview").classList.remove("stale");
    $("placeholder").hidden = true;
    $("length").textContent = `${response.headers.get("X-Paper-Length-MM")} mm`;
    prepared = request;
    readyRevision = current;
    notice();
  } catch (error) {
    if (current === revision && error.name !== "AbortError") {
      notice("error", error.message);
      if (error.message === "Renderer busy")
        timer = setTimeout(updatePreview, 800);
    }
  }
  printState();
}
$("print").onclick = async () => {
  if ($("print").disabled) return;
  const request = prepared;
  submitting = true;
  printState();
  notice("busy", "Submitting print…");
  try {
    const response = await api("jobs" + request.suffix, {
      method: "POST",
      body: request.body,
      headers: {
        "Content-Type": request.type,
        "Idempotency-Key": randomToken(),
      },
    });
    await response.json();
    notice("success", "Print submitted.");
    await refresh();
  } catch (error) {
    notice(
      "error",
      `${error.message}. Submission may have reached the printer; verify before printing again.`,
    );
  } finally {
    submitting = false;
    printState();
  }
};
async function refresh() {
  try {
    const status = await (await api("status")).json();
    available = status.available;
    indicator(
      "status",
      available ? "success" : "offline",
      available ? "Printer ready" : `Printer unavailable · ${status.state}`,
    );
  } catch {
    available = false;
    indicator("status", "offline", "Printer service unavailable");
  }
  printState();
}
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch(() => {});
}
async function openSharedContent() {
  const url = new URL(location.href);
  const token = url.searchParams.get("share");
  if (!token) return;
  url.searchParams.delete("share");
  history.replaceState(null, "", url);
  try {
    if (!/^[a-f0-9-]{36}$/.test(token))
      throw new Error(
        "Could not receive shared content. Please share it again.",
      );
    const cache = await caches.open("catprinter-incoming-shares");
    const key = new URL("/share-target/" + token, location.origin);
    const response = await cache.match(key);
    await cache.delete(key);
    if (
      !response ||
      Date.now() - Number(response.headers.get("X-Share-Created")) > 3600000
    )
      throw new Error("Shared content expired. Please share it again.");
    const data = await response.formData();
    const images = data
      .getAll("images")
      .filter((file) => file instanceof File && file.size);
    const text = ["title", "text", "url"]
      .map((name) => data.get(name))
      .filter((value) => typeof value === "string" && value.trim());
    const content = [...new Set(text)].join("\n\n");
    if (content) $("markdown").value = content;
    if (images.length) {
      selectTab("image");
      await loadImage(images);
    } else if (content) {
      selectTab("markdown");
    } else {
      throw new Error("No supported text or images were shared.");
    }
  } catch (error) {
    notice("error", error.message);
  }
}
changed();
refresh();
openSharedContent();
setInterval(() => {
  if (!document.hidden) refresh();
}, 10000);
window.addEventListener("focus", refresh);
