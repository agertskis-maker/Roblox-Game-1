const zlib = require('zlib');
const fs = require('fs');
function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
// rgb: Buffer w*h*3 (channels=3) or w*h*4 (channels=4)
function encode(w, h, data, channels) {
  channels = channels || 3;
  const raw = Buffer.alloc((w * channels + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * channels + 1)] = 0;
    data.copy(raw, y * (w * channels + 1) + 1, y * w * channels, (y + 1) * w * channels);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = channels === 4 ? 6 : 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
function decode(buf) {
  let p = 8, w, h, ct, bd, idat = [], plte = null;
  while (p < buf.length) {
    const len = buf.readUInt32BE(p); const type = buf.toString('latin1', p + 4, p + 8); const d = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); bd = d[8]; ct = d[9]; }
    else if (type === 'PLTE') plte = d;
    else if (type === 'IDAT') idat.push(d);
    p += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[ct];
  const bpp = ch;
  const stride = w * ch;
  const out = Buffer.alloc(stride * h);
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const cur = out.subarray(y * stride, (y + 1) * stride);
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? cur[x - bpp] : 0, b = prev[x], c = x >= bpp ? prev[x - bpp] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c); v += (pa <= pb && pa <= pc) ? a : pb <= pc ? b : c; }
      cur[x] = v & 255;
    }
    prev = cur;
  }
  // convert to RGB
  const rgb = Buffer.alloc(w * h * 3);
  for (let i = 0; i < w * h; i++) {
    if (ct === 2) { rgb[i * 3] = out[i * 3]; rgb[i * 3 + 1] = out[i * 3 + 1]; rgb[i * 3 + 2] = out[i * 3 + 2]; }
    else if (ct === 6) { rgb[i * 3] = out[i * 4]; rgb[i * 3 + 1] = out[i * 4 + 1]; rgb[i * 3 + 2] = out[i * 4 + 2]; }
    else if (ct === 0) { rgb[i * 3] = rgb[i * 3 + 1] = rgb[i * 3 + 2] = out[i]; }
    else if (ct === 3) { const k = out[i]; rgb[i * 3] = plte[k * 3]; rgb[i * 3 + 1] = plte[k * 3 + 1]; rgb[i * 3 + 2] = plte[k * 3 + 2]; }
    else if (ct === 4) { rgb[i * 3] = rgb[i * 3 + 1] = rgb[i * 3 + 2] = out[i * 2]; }
  }
  return { w, h, rgb };
}
module.exports = { encode, decode, write: (f, w, h, d, c) => fs.writeFileSync(f, encode(w, h, d, c)), read: (f) => decode(fs.readFileSync(f)) };
