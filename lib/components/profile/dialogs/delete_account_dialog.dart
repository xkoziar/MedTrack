import 'package:flutter/material.dart';

import 'package:med_track/components/common/custom_text_field.dart';
import 'package:med_track/utils/constants.dart';
import 'package:med_track/utils/validators.dart';

class DeleteAccountDialog extends StatefulWidget {
  final Future<void> Function(String password) onDelete;

  const DeleteAccountDialog({super.key, required this.onDelete});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController passwordCtrl;

  @override
  void initState() {
    super.initState();
    passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Delete Account",
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "This action cannot be undone.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              label: "Password",
              obscure: true,
              controller: passwordCtrl,
              validator: Validators.loginPassword,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;

            final navigator = Navigator.of(context);
            await widget.onDelete(passwordCtrl.text);

            navigator.pop();
          },
          child: Text(
            "Delete",
            style: TextStyle(color: AppColors.errorBackground),
          ),
        ),
      ],
    );
  }
}
