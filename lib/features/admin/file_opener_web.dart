import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void openBytesInBrowser(List<int> bytes, String contentType) {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: contentType));
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  // Give the new tab time to load before releasing the memory
  Future.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
