import 'dart:typed_data';
import 'package:gal/gal.dart';

Future<void> savePng(Uint8List bytes, String name) async {
  if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
    throw StateError('Gallery permission was not granted.');
  }
  await Gal.putImageBytes(bytes, album: 'Panpanskii', name: name);
}
