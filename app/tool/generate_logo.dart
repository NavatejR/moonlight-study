// Generates the Moonlight Study app icon (a groove vinyl + crescent moon)
// across all platforms using the bundled `image` package:
//
//   dart run tool/generate_logo.dart
//
// Written PNGs:
//   - macOS:   macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png
//   - iOS:     ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png
//   - Android: android/app/src/main/res/mipmap-*/ic_launcher.png
//   - Windows: windows/runner/resources/app_icon.ico (multi-size)
//   - Linux:   linux/runner/resources/app_icon.png
//
import 'dart:io';

import 'package:image/image.dart' as img;

// Coffee palette (mirrors lib/core/theme/colors.dart + vinyldisc.dart).
const _vinyl = 0xFF17130F; // disc edge / canvas
const _discBody = 0xFF241C15; // espresso disc body
const _groove = 0x22FFFFFF; // faint groove rings (ARGB: 13% white)
const _label = 0xFFF0E1C3; // warm cream label
const _labelBorder = 0xFFC79A6B; // caramel ring around the label
const _espresso = 0xFF241A11; // moon / warm dark
const _caramel = 0xFFC08A55; // accent dot

img.Color _argb(int value) {
  final a = (value >> 24) & 0xFF;
  final r = (value >> 16) & 0xFF;
  final g = (value >> 8) & 0xFF;
  final b = value & 0xFF;
  return img.ColorRgba8(r, g, b, a);
}

/// Renders the logo at pixel size [side] with 4x supersampling for smooth
/// edges. [simple] drops grooves + crescent detail for sub-40px icons where
/// they would only turn to mush.
img.Image _render(int side, {required bool simple}) {
  final s = side * 4;
  final image = img.Image(width: s, height: s);
  img.fill(image, color: _argb(_vinyl));

  final r = s / 2;
  img.fillCircle(image,
      x: s ~/ 2, y: s ~/ 2, radius: (r * 0.97).round(), color: _argb(_vinyl));
  img.fillCircle(image,
      x: s ~/ 2,
      y: s ~/ 2,
      radius: (r * 0.93).round(),
      color: _argb(_discBody));

  if (!simple) {
    // Grooves (thin outlines survive the supersample downscale).
    final grooveColor = _argb(_groove);
    for (var i = 0; i < 9; i++) {
      img.drawCircle(
        image,
        x: s ~/ 2,
        y: s ~/ 2,
        radius: (r * (0.40 + i * 0.05)).round(),
        color: grooveColor,
        antialias: true,
      );
    }
  }

  // Center label.
  final labelR = r * (simple ? 0.56 : 0.44);
  img.fillCircle(image,
      x: s ~/ 2,
      y: s ~/ 2,
      radius: labelR.round(),
      color: _argb(_label),
      antialias: true);
  if (!simple) {
    img.drawCircle(image,
        x: s ~/ 2,
        y: s ~/ 2,
        radius: (labelR * 0.98).round(),
        color: _argb(_labelBorder),
        antialias: true);
  }

  // Crescent moon carved out of the label.
  final moonR = r * (simple ? 0.30 : 0.22);
  final cx = s ~/ 2 - (r * (simple ? 0.02 : 0.10)).round();
  final cy = s ~/ 2 - (r * (simple ? 0.02 : 0.12)).round();
  img.fillCircle(image,
      x: cx, y: cy, radius: moonR.round(), color: _argb(_espresso), antialias: true);
  img.fillCircle(image,
      x: s ~/ 2 - (r * 0.02).round(),
      y: s ~/ 2,
      radius: moonR.round(),
      color: _argb(_label),
      antialias: true);
  img.fillCircle(image,
      x: s ~/ 2 + (r * (simple ? 0.05 : 0.04)).round(),
      y: s ~/ 2 + (r * (simple ? 0.05 : 0.06)).round(),
      radius: (r * 0.045).round(),
      color: _argb(_espresso),
      antialias: true);

  img.fillCircle(image,
      x: s ~/ 2 + (r * 0.30).round(),
      y: s ~/ 2 + (r * 0.24).round(),
      radius: (r * 0.05).round(),
      color: _argb(_caramel),
      antialias: true);

  return img.copyResize(image,
      width: side, height: side, interpolation: img.Interpolation.average);
}

void _writePng(String path, int side) {
  final png = img.encodePng(_render(side, simple: side <= 40));
  File(path)..createSync(recursive: true)..writeAsBytesSync(png);
  stdout.writeln('  wrote $path (${png.length} bytes)');
}

void _writeIco(String path) {
  final frames = <img.Image>[
    for (final side in const [256, 128, 64, 48, 32, 16])
      _render(side, simple: side <= 40),
  ];
  final bytes = img.IcoEncoder().encodeImages(frames);
  File(path)..createSync(recursive: true)..writeAsBytesSync(bytes);
  stdout.writeln('  wrote $path (${bytes.length} bytes)');
}

/// Generates the iOS asset set with the exact filenames referenced by
/// Contents.json.
void _writeIos() {
  final entries = <(String, int)>[
    ('Icon-App-20x20@1x.png', 20),
    ('Icon-App-20x20@2x.png', 40),
    ('Icon-App-20x20@3x.png', 60),
    ('Icon-App-29x29@1x.png', 29),
    ('Icon-App-29x29@2x.png', 58),
    ('Icon-App-29x29@3x.png', 87),
    ('Icon-App-40x40@1x.png', 40),
    ('Icon-App-40x40@2x.png', 80),
    ('Icon-App-40x40@3x.png', 120),
    ('Icon-App-60x60@2x.png', 120),
    ('Icon-App-60x60@3x.png', 180),
    ('Icon-App-76x76@1x.png', 76),
    ('Icon-App-76x76@2x.png', 152),
    ('Icon-App-83.5x83.5@2x.png', 167),
    ('Icon-App-1024x1024@1x.png', 1024),
  ];
  final dir =
      'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final (name, side) in entries) {
    _writePng('$dir/$name', side);
  }
}

void main() {
  // macOS
  final macDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final side in const [16, 32, 64, 128, 256, 512, 1024]) {
    _writePng('$macDir/app_icon_$side.png', side);
  }

  // iOS
  _writeIos();

  // Android
  final androidDir = 'android/app/src/main/res';
  final sizes = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in sizes.entries) {
    _writePng('$androidDir/${entry.key}/ic_launcher.png', entry.value);
  }

  // Windows
  _writeIco('windows/runner/resources/app_icon.ico');

  // Linux
  _writePng('linux/runner/resources/app_icon.png', 512);

  stdout.writeln('done.');
}