#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const desktopRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const assetsRoot = path.join(desktopRoot, 'assets');
const iconEntries = [
  ['icon_16x16.png', 16],
  ['icon_16x16@2x.png', 32],
  ['icon_32x32.png', 32],
  ['icon_32x32@2x.png', 64],
  ['icon_128x128.png', 128],
  ['icon_128x128@2x.png', 256],
  ['icon_256x256.png', 256],
  ['icon_256x256@2x.png', 512],
  ['icon_512x512.png', 512],
  ['icon_512x512@2x.png', 1024],
];

if (process.platform !== 'darwin') {
  throw new Error('macOS icon preparation requires iconutil.');
}

for (const name of ['icon', 'icon-staging']) {
  const source = path.join(assetsRoot, `${name}.png`);
  const iconset = path.join(assetsRoot, `${name}.iconset`);
  const output = path.join(assetsRoot, `${name}.icns`);
  try {
    await mkdir(iconset, { recursive: true });
    for (const [file, size] of iconEntries) {
      await sharp(source).resize(size, size).png().toFile(path.join(iconset, file));
    }
    const result = spawnSync('iconutil', ['-c', 'icns', iconset, '-o', output], {
      encoding: 'utf8',
    });
    if (result.error) throw result.error;
    if (result.status !== 0) {
      throw new Error(result.stderr || result.stdout || `iconutil exited ${result.status}`);
    }
  } finally {
    await rm(iconset, { recursive: true, force: true });
  }
}
