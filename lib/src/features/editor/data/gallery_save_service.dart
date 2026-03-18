import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

class GallerySaveService {
  const GallerySaveService();

  Future<bool> saveJpeg(Uint8List bytes) async {
    if (kIsWeb) {
      return false;
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'photo_editor_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final saved = await GallerySaver.saveImage(
      file.path,
      albumName: 'PhotoEditorAI',
      // toDcim saves into DCIM folder on Android; not applicable on iOS.
      toDcim: Platform.isAndroid,
    );

    return saved ?? false;
  }
}
