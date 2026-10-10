import 'package:flutter/material.dart';

/// "Fragile", "Age check", "Leave with neighbour" — tapping a tag shows what it asks of the driver.
class StopChip extends StatelessWidget {
  const StopChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(padding: const EdgeInsets.all(24), child: Text(label)),
      ),
    );
  }
}
