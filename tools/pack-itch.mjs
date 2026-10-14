// Zips the Godot web export (build/web) for an itch.io HTML upload.
// itch.io serves the archive's root index.html inside an iframe, so the export
// must be named index.html (the "Web" preset already writes ../build/web/index.html).
//
// Usage: node tools/pack-itch.mjs [exportDir] [outZip]
// Plain Node 20+, no dependencies.
import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';
import * as zlib from 'node:zlib';

// zlib.crc32 arrived in Node 20.15 / 22.2; package.json allows any Node 20, so
// fall back to a table CRC-32 (same polynomial as zip) when it is missing.
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = zlib.crc32 ?? ((buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
});
const { deflateRawSync } = zlib;

const root = process.argv[2] ?? 'build/web';
const out = process.argv[3] ?? 'release/dead-mans-hand-itch-web.zip';
const version = /^config\/version="(.*)"$/m.exec(readFileSync('godot/project.godot', 'utf8'))?.[1] ?? '?';

// Godot leaves index.wasm<random>.tmp files behind when an export is interrupted;
// they are 10 MB each and never loaded, so only ship what the export produces.
const walk = (dir) => readdirSync(dir, { withFileTypes: true })
  .flatMap((d) => (d.isDirectory() ? walk(join(dir, d.name)) : [join(dir, d.name)]))
  .filter((f) => !f.endsWith('.tmp'))
  .sort();

let files;
try {
  files = walk(root);
} catch {
  throw new Error(`${root} not found — export the "Web" preset first (see docs/itch/README.md)`);
}
const names = new Set(files.map((f) => relative(root, f).split(sep).join('/')));
for (const required of ['index.html', 'index.js', 'index.wasm', 'index.pck']) {
  if (!names.has(required)) throw new Error(`${root}/${required} missing — export the "Web" preset first`);
}

// DOS date/time of the newest file, so re-packing the same export gives the same archive.
const when = new Date(Math.max(...files.map((f) => statSync(f).mtimeMs)));
const dosTime = (when.getHours() << 11) | (when.getMinutes() << 5) | (when.getSeconds() >> 1);
const dosDate = ((when.getFullYear() - 1980) << 9) | ((when.getMonth() + 1) << 5) | when.getDate();

const locals = [];
const central = [];
let offset = 0;
for (const file of files) {
  const name = Buffer.from(relative(root, file).split(sep).join('/'), 'utf8');
  const data = readFileSync(file);
  const packed = deflateRawSync(data, { level: 9 });
  const crc = crc32(data);
  const head = Buffer.alloc(30);
  head.writeUInt32LE(0x04034b50, 0);
  head.writeUInt16LE(20, 4); // version needed
  head.writeUInt16LE(0x0800, 6); // UTF-8 names
  head.writeUInt16LE(8, 8); // deflate
  head.writeUInt16LE(dosTime, 10);
  head.writeUInt16LE(dosDate, 12);
  head.writeUInt32LE(crc, 14);
  head.writeUInt32LE(packed.length, 18);
  head.writeUInt32LE(data.length, 22);
  head.writeUInt16LE(name.length, 26);
  locals.push(head, name, packed);

  const dir = Buffer.alloc(46);
  dir.writeUInt32LE(0x02014b50, 0);
  dir.writeUInt16LE(20, 4); // made by
  dir.writeUInt16LE(20, 6);
  dir.writeUInt16LE(0x0800, 8);
  dir.writeUInt16LE(8, 10);
  dir.writeUInt16LE(dosTime, 12);
  dir.writeUInt16LE(dosDate, 14);
  dir.writeUInt32LE(crc, 16);
  dir.writeUInt32LE(packed.length, 20);
  dir.writeUInt32LE(data.length, 24);
  dir.writeUInt16LE(name.length, 28);
  dir.writeUInt32LE(offset, 42);
  central.push(dir, name);
  offset += head.length + name.length + packed.length;
}
const dirSize = central.reduce((n, b) => n + b.length, 0);
const end = Buffer.alloc(22);
end.writeUInt32LE(0x06054b50, 0);
end.writeUInt16LE(files.length, 8);
end.writeUInt16LE(files.length, 10);
end.writeUInt32LE(dirSize, 12);
end.writeUInt32LE(offset, 16);

mkdirSync(dirname(out), { recursive: true });
const zip = Buffer.concat([...locals, ...central, end]);
writeFileSync(out, zip);
console.log(`${out}: v${version}, ${files.length} files, ${(zip.length / 1024 / 1024).toFixed(1)} MB`);
