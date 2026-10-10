import { StyleSheet, Text, View } from 'react-native';

import { colors, type } from '../theme/colors';
import { formatPrice } from '../utils/money';

type Props = { cents: number; wasCents?: number; unit?: string };

export function PriceTag({ cents, wasCents, unit }: Props) {
  return (
    <View style={styles.row}>
      <Text style={styles.price} allowFontScaling={false}>
        {formatPrice(cents)}
      </Text>
      {unit ? <Text style={styles.unit}>/ {unit}</Text> : null}
      {wasCents ? <Text style={styles.was}>{formatPrice(wasCents)}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'baseline', gap: 6 },
  price: { fontSize: type.body, fontWeight: '600', color: colors.text },
  unit: { fontSize: type.caption, color: colors.textMuted },
  was: { fontSize: type.caption, color: colors.textMuted, textDecorationLine: 'line-through' },
});
