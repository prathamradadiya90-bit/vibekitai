import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class CardExportService {
  CardExportService._();

  /// Captures the widget inside the RepaintBoundary as raw PNG bytes (pixelRatio 3.0).
  /// Universally safe and runs on both Mobile and Web platforms without path_provider crashes.
  static Future<Uint8List?> captureCardBytes(GlobalKey boundaryKey) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('CardExportService: Boundary render object not found.');
        return null;
      }

      // Render at 3.0 pixel ratio for crisp high-dpi card output
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      Uint8List? pngBytes;
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          pngBytes = byteData.buffer.asUint8List();
        }
      } finally {
        image.dispose();
      }
      return pngBytes;
    } catch (e) {
      debugPrint('CardExportService.captureCardBytes error: $e');
      return null;
    }
  }

  /// Captures the widget inside the RepaintBoundary as a high-resolution PNG image.
  /// On Mobile: saves to temporary cache and returns file path.
  /// On Web: returns a virtual identifier to prevent MissingPluginException from path_provider.
  static Future<String?> captureAndSaveCard(GlobalKey boundaryKey,
      {String? filename}) async {
    try {
      final pngBytes = await captureCardBytes(boundaryKey);
      if (pngBytes == null) return null;

      final name = filename ??
          'vibekit_card_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        return 'web_export:$name';
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$name');

      await file.writeAsBytes(pngBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('CardExportService error: $e');
      return null;
    }
  }
}
