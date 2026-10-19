import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../offline/proof_outbox.dart';

/// Signature and recipient name at the door. Leaving with a half-drawn signature asks first.
class ProofScreen extends StatefulWidget {
  const ProofScreen({super.key, required this.stopId});

  final String stopId;

  @override
  State<ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends State<ProofScreen> {
  final _recipient = TextEditingController();
  String _signatureSvg = '';

  bool get _dirty => _signatureSvg.isNotEmpty || _recipient.text.isNotEmpty;

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        content: const Text('Discard this signature?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    final outbox = await ProofOutbox.open();
    outbox.add(
      Proof(id: '${widget.stopId}-${DateTime.now().millisecondsSinceEpoch}', stopId: widget.stopId,
          signatureSvg: _signatureSvg, recipient: _recipient.text),
      () => context.go('/stops'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_dirty || await _confirmDiscard(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Proof of delivery')),
        body: Column(children: [
          TextField(controller: _recipient, decoration: const InputDecoration(labelText: 'Received by')),
          Expanded(child: SignaturePad(onChanged: (svg) => setState(() => _signatureSvg = svg))),
          FilledButton(onPressed: _save, child: const Text('Delivered')),
        ]),
      ),
    );
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
