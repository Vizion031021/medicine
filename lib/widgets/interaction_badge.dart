import 'package:flutter/material.dart';
import 'package:sseudeuson/models/medicine_model.dart';

class InteractionBadge extends StatelessWidget {
  final InteractionSeverity severity;

  const InteractionBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: severity.bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          fontSize: 10,
          color: severity.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
