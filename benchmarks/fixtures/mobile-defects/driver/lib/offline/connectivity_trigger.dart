import 'package:connectivity_plus/connectivity_plus.dart';

import 'proof_outbox.dart';

/// Any network change is a chance to send what the outbox holds; the drain itself decides whether the API answers.
void drainOnNetworkChange() {
  Connectivity().onConnectivityChanged.listen((_) async {
    final outbox = await ProofOutbox.open();
    await outbox.drain();
  });
}
