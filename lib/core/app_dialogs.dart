import 'package:flutter/material.dart';

BuildContext? _rootContext;

void setRootContext(BuildContext context) {
  _rootContext = context;
}

void showGlobalDialog({
  required String title,
  required String message,
}) {
  final ctx = _rootContext;
  
  if (ctx == null) {
    debugPrint('❌ Global context is null, cannot show dialog');
    return;
  }

  showDialog(
    context: ctx,
    useRootNavigator: true,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  debugPrint('🟢 showGlobalDialog called successfully');
}

