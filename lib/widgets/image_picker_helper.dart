import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/ids.dart';

class ImagePickerHelper {
  static final _picker = ImagePicker();

  /// Seleciona uma imagem e devolve um caminho persistível.
  /// No web, grava como data URL (base64) porque não há filesystem local.
  static Future<String?> pickAndStore({ImageSource source = ImageSource.gallery}) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return null;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? _mimeFromName(picked.name) ?? 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
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
    if (path == null || path.isEmpty || isRemote(path) || isDataUrl(path)) return null;
    if (kIsWeb) return null;
    final direct = File(path);
    if (await direct.exists()) return direct;
    final docs = await getApplicationDocumentsDirectory();
    final nested = File(p.join(docs.path, path));
    if (await nested.exists()) return nested;
    return null;
  }

  static Uint8List? dataUrlBytes(String path) {
    if (!isDataUrl(path)) return null;
    final comma = path.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(path.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static bool isDataUrl(String path) => path.startsWith('data:');

  static bool isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  static String? _mimeFromName(String? name) {
    if (name == null) return null;
    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.jpg' || '.jpeg' => 'image/jpeg',
      _ => null,
    };
  }
}
