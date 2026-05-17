import 'package:flutter/material.dart';
import 'package:ultra_sync/core/theme/app_theme.dart';

/// Centralised SnackBar helper — eliminates copy-paste styling across pages.
abstract class AppSnackBar {
  static void showError(BuildContext context, String message) =>
      _show(context, message: message, color: AppColors.error);

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message: message, color: AppColors.success);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message: message, color: AppColors.info);

  static void _show(
    BuildContext context, {
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}
