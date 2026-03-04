/// Run this script to generate splash logo PNGs.
///
/// Usage:
///   dart run tool/generate_splash_pngs.dart
///
/// This creates placeholder splash logos. For production, replace with
/// a properly designed 1152x1152 PNG logo.
///
/// Alternatively, you can use any PNG editor to create:
///   assets/images/splash_logo.png       (1152x1152, dark logo on transparent)
///   assets/images/splash_logo_dark.png  (1152x1152, white logo on transparent)
///
/// For now, create minimal placeholder PNGs so flutter_native_splash can run.
library;

import 'dart:io';
import 'dart:typed_data';

// Minimal 1x1 transparent PNG
final _transparentPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
  0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00, // IEND chunk
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

void main() {
  final dir = Directory('assets/images');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  File('assets/images/splash_logo.png').writeAsBytesSync(_transparentPng);
  File('assets/images/splash_logo_dark.png').writeAsBytesSync(_transparentPng);

  print('Created placeholder splash PNGs in assets/images/');
  print('Replace these with your actual 1152x1152 brand logos for production.');
}
