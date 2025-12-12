import 'package:flutter/material.dart';
import 'package:med_track/utils/constants.dart';
import '../../../components/custom_text_field.dart';
import '../../../utils/validators.dart';

class ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String currentPassword, String newPassword)
  onSubmit;

  const ChangePasswordDialog({super.key, required this.onSubmit});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController currentCtrl;
  late final TextEditingController newCtrl;
  late final TextEditingController confirmCtrl;

  @override
  void initState() {
    super.initState();
    currentCtrl = TextEditingController();
    newCtrl = TextEditingController();
    confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Change Password"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: "Current Password",
                obscure: true,
                controller: currentCtrl,
                validator: Validators.loginPassword,
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                label: "New Password",
                obscure: true,
                controller: newCtrl,
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.lg),
              CustomTextField(
                label: "Confirm Password",
                obscure: true,
                controller: confirmCtrl,
                validator: (value) =>
                    Validators.confirmPassword(newCtrl.text, value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;

            final navigator = Navigator.of(context);
            await widget.onSubmit(currentCtrl.text, newCtrl.text);

            navigator.pop();
          },
          child: const Text("Change"),
        ),
      ],
    );
  }
}
