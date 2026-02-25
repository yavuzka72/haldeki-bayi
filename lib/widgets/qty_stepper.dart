import 'package:flutter/material.dart';

class QtyStepper extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const QtyStepper({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChanged((value - 1).clamp(0, 999).toDouble()),
          icon: const Icon(Icons.remove),
        ),
        Text(value.toStringAsFixed(0)),
        IconButton(
          onPressed: () => onChanged((value + 1).clamp(0, 999).toDouble()),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
