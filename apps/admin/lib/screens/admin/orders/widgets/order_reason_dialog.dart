import 'package:flutter/material.dart';

/// ADMR-35: a real operator reason, captured once, shared by every order
/// action that requires one — previously each caller either sent no reason
/// at all or a client-generated description ("Status updated to X.") that
/// trivially satisfied the backend's own non-empty check without ever
/// reflecting why an operator actually made the change. Deliberately a single
/// combined dialog (warning copy + reason field) rather than two sequential
/// popups.
///
/// Returns the trimmed reason on confirm, or null if the operator cancelled.
Future<String?> promptOrderActionReason({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Continue',
  Color confirmColor = Colors.red,
  int minLength = 3,
  int maxLength = 500,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final trimmed = controller.text.trim();
        final isValid = trimmed.length >= minLength && trimmed.length <= maxLength;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: maxLength,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Reason for this change',
                  border: const OutlineInputBorder(),
                  errorText: controller.text.isNotEmpty && trimmed.length < minLength
                      ? 'At least $minLength characters'
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isValid ? () => Navigator.pop(context, trimmed) : null,
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
              child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}
