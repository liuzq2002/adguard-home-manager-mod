import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

class MasterSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChange;
  final EdgeInsets? margin;

  const MasterSwitch(
      {super.key,
      required this.label,
      required this.value,
      required this.onChange,
      this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      child: MiuixCard(
        cornerRadius: 28,
        insideMargin: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        onPressed: () => onChange(!value),
        feedbackType: MiuixPressFeedbackType.sink,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            MiuixSwitch(
              value: value,
              onChanged: onChange,
            ),
          ],
        ),
      ),
    );
  }
}
