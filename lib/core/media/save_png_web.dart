import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> savePng(Uint8List bytes, String name) async {
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = '$name.png';
  try {
    web.document.body!.append(link);
    link.click();
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    link.remove();
    web.URL.revokeObjectURL(url);
  }
}
