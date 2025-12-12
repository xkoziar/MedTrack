import 'package:flutter/material.dart';

class ActiveChip extends StatelessWidget {
  final bool isActive;

  const ActiveChip({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bg =
        isActive ? const Color(0xFFD4EDDA) : const Color(0xFFFFF3CD);
    final fg =
        isActive ? const Color(0xFF155724) : const Color(0xFF856404);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Paused',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: fg,
          fontSize: 12,
        ),
      ),
    );
  }
}