import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Hand-over at the door: the driver checks the bags off, then confirms. Opened from the dispatch SMS link.
class HandoverScreen extends StatefulWidget {
  const HandoverScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _checked = <int>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order ${widget.orderId}')),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: 6,
            itemBuilder: (context, index) => CheckboxListTile(
              value: _checked.contains(index),
              onChanged: (on) => setState(() => on == true ? _checked.add(index) : _checked.remove(index)),
              title: Text('Bag ${index + 1}'),
            ),
          ),
          Positioned(left: 16, right: 16, bottom: 0, child: FilledButton(
            onPressed: _checked.length == 6
                ? () => api.post('/driver/orders/${widget.orderId}/handover', {'bags': _checked.length})
                : null,
            child: const Text('Confirm hand-over'),
          )),
        ],
      ),
    );
  }
}
