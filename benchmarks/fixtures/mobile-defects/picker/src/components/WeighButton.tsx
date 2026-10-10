import { useState } from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';

import { readWeight, tare } from '../native/scale';
import { colors } from '../theme/colors';

/** Tares the crate, then reads the produce weight for a loose-weight line. */
export function WeighButton({ onWeighed }: { onWeighed: (grams: number) => void }) {
  const [busy, setBusy] = useState(false);

  async function weigh() {
    setBusy(true);
    try {
      await tare();
      const reading = await readWeight();
      if (reading.stable) onWeighed(reading.grams);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Pressable accessibilityRole="button" disabled={busy} onPress={weigh} style={styles.button}>
      <Text style={styles.label}>{busy ? 'Weighing…' : 'Weigh'}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { minWidth: 88, minHeight: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surfaceAlt },
  label: { fontSize: 15, fontWeight: '600', color: colors.text },
});
