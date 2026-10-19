import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

/// "Report a problem" at a stop. Back with an unsent note asks before throwing it away.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.stopId});

  final String stopId;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _note = TextEditingController();

  bool get _dirty => _note.text.trim().isNotEmpty;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _maybeLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        content: const Text('Discard this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep writing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybeLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Report a problem')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _note,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'What happened?'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => api.post('/driver/stops/${widget.stopId}/notes', {'text': _note.text}),
          label: const Text('Send'),
        ),
      ),
    );
  }
}
