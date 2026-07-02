import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ExportUtil {
  static Future<void> captureAndShare(
    ScreenshotController controller,
    BuildContext context,
  ) async {
    try {
      final image = await controller.capture(pixelRatio: 3.0);
      if (image == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/shift_summary.png');
      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: "My Shift Summary — Don't Work For Free",
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFFF1744),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
