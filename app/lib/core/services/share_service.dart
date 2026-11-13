import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService._();

  /// Builds a viral Google Play referral link tied to the user's installation id.
  static String buildReferralLink(String? installationId) {
    if (installationId == null || installationId.isEmpty) {
      return 'https://play.google.com/store/apps/details?id=com.vibekit.ai';
    }
    return 'https://play.google.com/store/apps/details?id=com.vibekit.ai&referrer=ref_$installationId';
  }

  /// Appends viral referral footer to shared text.
  static String formatShareText(String text, {String? installationId}) {
    final link = buildReferralLink(installationId);
    return '$text\n\n✨ Made with VibeKit AI — Get it on Google Play: $link';
  }

  /// Copies text to system clipboard and shows a snackbar confirmation.
  static Future<void> copyToClipboard(BuildContext context, String text,
      {String? message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Copied to clipboard!'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Triggers Android's native share sheet with text and optional referral footer.
  static Future<void> shareText(String text, {String? subject, String? installationId}) async {
    final body = installationId != null ? formatShareText(text, installationId: installationId) : text;
    await Share.share(
      body,
      subject: subject ?? 'Created with VibeKit AI',
    );
  }

  /// Triggers native share sheet with an exported image file or raw bytes.
  /// Works safely on Android, iOS, and Web.
  static Future<void> shareImage(
    String filePath, {
    String? text,
    String? installationId,
    Uint8List? imageBytes,
  }) async {
    final formattedCaption = text != null
        ? (installationId != null ? formatShareText(text, installationId: installationId) : text)
        : (installationId != null ? '✨ Created with VibeKit AI: ${buildReferralLink(installationId)}' : 'Created with VibeKit AI');

    if (kIsWeb) {
      if (imageBytes != null) {
        await Share.shareXFiles(
          [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'vibekit_card.png')],
          text: formattedCaption,
        );
      } else {
        await shareText(formattedCaption);
      }
      return;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      await shareText(formattedCaption);
      return;
    }
    final xFile = XFile(filePath);
    await Share.shareXFiles(
      [xFile],
      text: formattedCaption,
    );
  }
}
