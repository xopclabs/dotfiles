// Keep the large HEIF decoder off the normal image-loading path.
let heicDecoder;
async function isHeif(file) {
  if (/\.(heic|heif|hif)$/i.test(file.name || "") ||
      /^image\/hei[cf](?:-sequence)?$/i.test(file.type)) return true;
  const header = new Uint8Array(await file.slice(0, 64).arrayBuffer());
  const brand = (offset) => String.fromCharCode(...header.slice(offset, offset + 4));
  if (brand(4) !== "ftyp") return false;
  for (let offset = 8; offset + 4 <= header.length; offset += 4) {
    if (offset === 12) continue; // Minor version, not a brand.
    if (["heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1"].includes(brand(offset)))
      return true;
  }
  return false;
}

export async function decodeImage(file) {
  try {
    // BMP, GIF, AVIF, etc. need no extra library when supported natively.
    return await createImageBitmap(file);
  } catch {
    if (!await isHeif(file))
      throw new Error("This image is damaged or its format is not supported by your browser.");
  }
  try {
    heicDecoder ||= import("./heic-to.js").catch((error) => {
      heicDecoder = null; // Allow retry after a transient network failure.
      throw error;
    });
    const { heicTo } = await heicDecoder;
    const png = await heicTo({ blob: file, type: "image/png" });
    return await createImageBitmap(png);
  } catch {
    throw new Error("Could not decode this HEIC/HEIF image. Try exporting it as JPEG or PNG.");
  }
}
