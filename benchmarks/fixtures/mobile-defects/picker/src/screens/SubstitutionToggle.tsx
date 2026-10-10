import { StyleSheet, Switch, Text, View } from 'react-native';

import { colors } from '../theme/colors';

type Props = { value: boolean; onChange: (next: boolean) => void };

/** Whether the picker may swap this line for a similar product when it is out of stock. */
export function SubstitutionToggle({ value, onChange }: Props) {
  return (
    <View accessible style={styles.row}>
      <Text style={styles.label}>Substitute if out of stock</Text>
      <Switch value={value} onValueChange={onChange} />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', minHeight: 48 },
  label: { fontSize: 14, color: colors.textMuted },
});
