import { Pressable, StyleSheet, Text, View } from 'react-native';
import Swipeable from 'react-native-gesture-handler/ReanimatedSwipeable';

import { colors, type } from '../theme/colors';
import type { Address } from '../state/addresses';

type Props = { address: Address; onDelete: (id: string) => void; onEdit: (id: string) => void };

/** A saved address. Swipe left to delete; screen-reader users get the same action from the actions rotor. */
export function SavedAddressRow({ address, onDelete, onEdit }: Props) {
  return (
    <Swipeable
      renderRightActions={() => (
        <Pressable accessibilityRole="button" onPress={() => onDelete(address.id)} style={styles.delete}>
          <Text style={styles.deleteLabel}>Delete</Text>
        </Pressable>
      )}
    >
      <View
        style={styles.row}
        accessible
        accessibilityActions={[
          { name: 'activate', label: 'Edit address' },
          { name: 'delete', label: 'Delete address' },
        ]}
        onAccessibilityAction={(event) => {
          if (event.nativeEvent.actionName === 'delete') onDelete(address.id);
          else onEdit(address.id);
        }}
      >
        <Text style={styles.label}>{address.label}</Text>
        <Text style={styles.line}>{address.line1}</Text>
      </View>
    </Swipeable>
  );
}

const styles = StyleSheet.create({
  row: { paddingHorizontal: 16, paddingVertical: 12, backgroundColor: colors.surface },
  label: { fontSize: type.body, fontWeight: '600', color: colors.text },
  line: { fontSize: type.caption, color: colors.textMuted },
  delete: { justifyContent: 'center', paddingHorizontal: 24, backgroundColor: colors.danger },
  deleteLabel: { color: colors.onBrand, fontWeight: '600' },
});
