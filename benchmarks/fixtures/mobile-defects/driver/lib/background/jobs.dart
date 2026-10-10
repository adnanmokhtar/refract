import 'package:workmanager/workmanager.dart';

import '../offline/proof_outbox.dart';

const syncTask = 'pantrygo.driver.sync';

/// Runs on a background isolate every 15 minutes and drains proofs captured while the phone had no signal.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == syncTask) {
      final outbox = await ProofOutbox.open();
      await outbox.drain();
    }
    return true;
  });
}

Future<void> registerBackgroundSync() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(syncTask, syncTask, frequency: const Duration(minutes: 15));
}
