import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';

type Props = { value: number; max: number; onChange: (next: number) => void };

export function QtyStepper({ value, max, onChange }: Props) {
  return (
    <View style={styles.row}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Fewer"
        disabled={value <= 0}
        onPress={() => onChange(value - 1)}
        style={styles.step}
      >
        <Text style={styles.stepLabel}>−</Text>
      </Pressable>
      <Text style={styles.value}>
        {value} / {max}
      </Text>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="More"
        disabled={value >= max}
        onPress={() => onChange(value + 1)}
        style={styles.step}
      >
        <Text style={styles.stepLabel}>+</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  step: { width: 32, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.surfaceAlt },
  stepLabel: { fontSize: 18, color: colors.text },
  value: { minWidth: 56, textAlign: 'center', fontSize: 15, color: colors.text },
});
