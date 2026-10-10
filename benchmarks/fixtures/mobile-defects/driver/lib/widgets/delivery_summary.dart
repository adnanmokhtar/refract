import 'package:flutter/material.dart';

/// "3 bags · £42.10" with the report-a-problem action beside it, read out as one line.
class DeliverySummary extends StatelessWidget {
  const DeliverySummary({super.key, required this.bagCount, required this.totalLabel, required this.onReportProblem});

  final int bagCount;
  final String totalLabel;
  final VoidCallback onReportProblem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$bagCount bags, $totalLabel',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(child: Text('$bagCount bags · $totalLabel')),
            TextButton(onPressed: onReportProblem, child: const Text('Report a problem')),
          ],
        ),
      ),
    );
  }
}
