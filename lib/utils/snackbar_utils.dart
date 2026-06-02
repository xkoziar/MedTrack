import 'package:flutter/material.dart';

void showSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: backgroundColor),
  );
}
