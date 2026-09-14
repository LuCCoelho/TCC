import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/ids.dart';

class ImagePickerHelper {
  static final _picker = ImagePicker();

  static Future<String?> pickAndStore({ImageSource source = ImageSource.gallery}) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 92);
    if (picked == null) return null;
    if (kIsWeb) {
      return picked.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docs.path, 'card_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final relative = p.join('card_images', '${newId()}$ext');
    final dest = File(p.join(docs.path, relative));
    await File(picked.path).copy(dest.path);
    return relative;
  }

  static Future<File?> resolveLocal(String? path) async {
    if (path == null || path.isEmpty || isRemote(path)) return null;
    if (kIsWeb) return null;
    final direct = File(path);
    if (await direct.exists()) return direct;
    final docs = await getApplicationDocumentsDirectory();
    final nested = File(p.join(docs.path, path));
    if (await nested.exists()) return nested;
    return null;
  }

  static bool isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');
}
