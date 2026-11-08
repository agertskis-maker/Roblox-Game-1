// Reads a Roblox cache texture (rbx-storage file: a 37-byte RBXH header, then a KTX2 file with BC1 or BC3 blocks, Zstandard
// supercompressed) and returns { w, h, rgb } for the top level. Node 24 only (zlib.zstdDecompressSync).
const fs = require('fs');
const zlib = require('zlib');

function c565(v) { return [((v >> 11) & 31) * 255 / 31, ((v >> 5) & 63) * 255 / 63, (v & 31) * 255 / 31]; }

function decodeColourBlock(b, o, out, w, bx, by, fourColour) {
  const c0 = b.readUInt16LE(o), c1 = b.readUInt16LE(o + 2);
  const p0 = c565(c0), p1 = c565(c1);
  const pal = [p0, p1, null, null];
  if (fourColour || c0 > c1) { pal[2] = p0.map((v, i) => (2 * v + p1[i]) / 3); pal[3] = p0.map((v, i) => (v + 2 * p1[i]) / 3); }
  else { pal[2] = p0.map((v, i) => (v + p1[i]) / 2); pal[3] = [0, 0, 0]; }
  const bits = b.readUInt32LE(o + 4);
  for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) {
    const idx = (bits >> (2 * (y * 4 + x))) & 3;
    const p = pal[idx];
    const q = ((by * 4 + y) * w + bx * 4 + x) * 3;
    out[q] = p[0]; out[q + 1] = p[1]; out[q + 2] = p[2];
  }
}

function decodeBC(data, w, h, bc3) {
  const out = new Uint8Array(w * h * 3);
  const bw = w / 4, bh = h / 4, size = bc3 ? 16 : 8;
  for (let by = 0; by < bh; by++) for (let bx = 0; bx < bw; bx++) {
    const o = (by * bw + bx) * size;
    decodeColourBlock(data, o + (bc3 ? 8 : 0), out, w, bx, by, bc3);
  }
  return out;
}

function read(file) {
  const raw = fs.readFileSync(file).subarray(37);
  if (raw.readUInt32BE(0) !== 0xab4b5458) throw new Error('not KTX2');
  const vk = raw.readUInt32LE(12), w = raw.readUInt32LE(20), h = raw.readUInt32LE(24), sc = raw.readUInt32LE(44);
  const levels = raw.readUInt32LE(40);
  const off = Number(raw.readBigUInt64LE(80)), len = Number(raw.readBigUInt64LE(88)), ulen = Number(raw.readBigUInt64LE(96));
  let data = raw.subarray(off, off + len);
  if (sc === 2) data = zlib.zstdDecompressSync(data);
  else if (sc !== 0) throw new Error('supercompression ' + sc);
  if (vk !== 137 && vk !== 131) throw new Error('format ' + vk);
  const rgb = decodeBC(data, w, h, vk === 137);
  return { w, h, rgb: Buffer.from(rgb.buffer), levels };
}
module.exports = { read };
