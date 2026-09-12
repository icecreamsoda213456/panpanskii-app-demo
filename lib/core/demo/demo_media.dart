import 'dart:convert';
import 'package:flutter/services.dart';

class DemoMedia {
  static final _urls = <String, Future<String>>{};
  static Future<Uint8List> bytes(String path) async {
    if (path.startsWith('asset:')) {
      return (await rootBundle.load(path.substring(6))).buffer.asUint8List();
    }
    return UriData.parse(path).contentAsBytes();
  }

  static Future<String> url(String path) => _urls.putIfAbsent(
      path,
      () async => path.startsWith('asset:')
          ? 'data:image/png;base64,${base64Encode(await bytes(path))}'
          : path);
}
