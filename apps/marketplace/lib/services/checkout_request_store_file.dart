import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'checkout_request_store.dart';

CheckoutRequestStore createCheckoutRequestStore() => FileCheckoutRequestStore();

/// Same-directory staged replacement keeps the previous record intact while
/// writing. This journal is for the foreground app isolate; server request
/// anchors remain the authority across devices and concurrent processes.
class FileCheckoutRequestStore implements CheckoutRequestStore {
  FileCheckoutRequestStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  static const maxBytes = 256 * 1024;

  Future<File> _file(String ownerId) async {
    if (ownerId.isEmpty || ownerId.length > 128) {
      throw const FormatException('Checkout recovery is unavailable.');
    }
    final root = await _directory();
    final folder = Directory('${root.path}/checkout_requests_v1');
    await folder.create(recursive: true);
    final name = base64Url.encode(utf8.encode(ownerId)).replaceAll('=', '');
    return File('${folder.path}/$name.json');
  }

  @override
  Future<String?> read(String ownerId) async {
    final file = await _file(ownerId);
    if (!await file.exists()) {
      // Never silently replace a possibly interrupted initial write.
      if (await File('${file.path}.next').exists()) {
        throw const FormatException('Checkout recovery needs attention.');
      }
      return null;
    }
    if (await file.length() > maxBytes) {
      throw const FormatException('Checkout recovery needs attention.');
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String ownerId, String value) async {
    if (utf8.encode(value).length > maxBytes) {
      throw const FormatException('Checkout details are too large.');
    }
    final file = await _file(ownerId);
    final staged = File('${file.path}.next');
    await staged.writeAsString(value, flush: true);
    await staged.rename(file.path);
  }

  @override
  Future<void> remove(String ownerId) async {
    final file = await _file(ownerId);
    if (await file.exists()) await file.delete();
    final staged = File('${file.path}.next');
    if (await staged.exists()) await staged.delete();
  }
}
