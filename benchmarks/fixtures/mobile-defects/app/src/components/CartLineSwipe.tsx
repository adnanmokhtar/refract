import { Pressable, StyleSheet, Text, View } from 'react-native';
import Swipeable from 'react-native-gesture-handler/ReanimatedSwipeable';

import { colors, type } from '../theme/colors';
import { formatPrice } from '../utils/money';
import type { CartLine } from '../state/cart';

type Props = { line: CartLine; onRemove: (id: string) => void };

/** A basket line. Swipe left to reveal Remove. */
export function CartLineSwipe({ line, onRemove }: Props) {
  return (
    <Swipeable
      friction={2}
      rightThreshold={40}
      renderRightActions={() => (
        <Pressable accessibilityRole="button" onPress={() => onRemove(line.id)} style={styles.remove}>
          <Text style={styles.removeLabel}>Remove</Text>
        </Pressable>
      )}
    >
      <View style={styles.row}>
        <Text style={styles.name}>{line.name}</Text>
        <Text style={styles.qty}>× {line.quantity}</Text>
        <Text style={styles.total}>{formatPrice(line.unitCents * line.quantity)}</Text>
      </View>
    </Swipeable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, backgroundColor: colors.surface },
  name: { flex: 1, fontSize: type.body, color: colors.text },
  qty: { fontSize: type.body, color: colors.textMuted, marginHorizontal: 12 },
  total: { fontSize: type.body, fontWeight: '600', color: colors.text },
  remove: { justifyContent: 'center', paddingHorizontal: 24, backgroundColor: colors.danger },
  removeLabel: { color: colors.onBrand, fontWeight: '600' },
});
