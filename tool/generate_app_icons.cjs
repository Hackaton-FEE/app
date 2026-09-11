#!/usr/bin/env node

// Package the approved artwork for Android without redrawing the brand.
// Requires sharp on Node's module path; see docs/app-icon.md.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const source = path.resolve(
  root,
  process.argv[2] || 'assets/logo/raster/osisnt_app_icon.png',
);
const symbol = path.join(root, 'assets/logo/vector/logo_monochrome.svg');
const resources = path.join(root, 'android/app/src/main/res');
const graphite = '#25272B';
const densities = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };

async function output(relative, contents) {
  const destination = path.join(resources, relative);
  await fs.mkdir(path.dirname(destination), { recursive: true });
  await fs.writeFile(destination, contents);
}

async function main() {
  const metadata = await sharp(source).metadata();
  if (!metadata.width || metadata.width !== metadata.height) {
    throw new Error('The approved app icon must be square.');
  }

  for (const [density, size] of Object.entries(densities)) {
    await output(
      `mipmap-${density}/ic_launcher.png`,
      await sharp(source).resize(size, size).png().toBuffer(),
    );
  }

  // Adaptive layers are 108dp (432px at xxxhdpi). The approved tile is
  // 90dp wide, keeping its visible symbol within the central 66dp safe area.
  // The launcher applies its own mask and clips the outer presentation tile.
  const tile = await sharp(source).resize(360, 360).png().toBuffer();
  const foreground = await sharp({
    create: { width: 432, height: 432, channels: 4, background: '#00000000' },
  })
    .composite([{ input: tile, left: 36, top: 36 }])
    .png()
    .toBuffer();
  await output('drawable-xxxhdpi/ic_launcher_foreground.png', foreground);

  // Android uses the alpha channel for themed icons. The original vector
  // symbol gives a clean silhouette, rather than tinting the solid tile.
  const monochrome = await sharp(symbol, { density: 384 })
    .resize(264, 264, { fit: 'contain', background: '#00000000' })
    .extend({ top: 84, bottom: 84, left: 84, right: 84, background: '#00000000' })
    .png()
    .toBuffer();
  await output('drawable-xxxhdpi/ic_launcher_monochrome.png', monochrome);
  await output(
    'drawable/ic_launcher_background.xml',
    `<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="${graphite}" />\n</shape>\n`,
  );

  for (const api of [26, 33]) {
    const monochromeLayer = api >= 33
      ? '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
      : '';
    await output(
      `mipmap-anydpi-v${api}/ic_launcher.xml`,
      '<?xml version="1.0" encoding="utf-8"?>\n' +
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n' +
        '    <background android:drawable="@drawable/ic_launcher_background" />\n' +
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n' +
        monochromeLayer +
        '</adaptive-icon>\n',
    );
  }
  console.log('Generated five legacy icons and Android adaptive/themed resources.');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
