import { useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { ProductThumb } from '../components/ProductThumb';
import { WeighButton } from '../components/WeighButton';
import { colors } from '../theme/colors';
import type { PickLine } from '../utils/group';
import { QtyStepper } from './QtyStepper';
import { SubstitutionToggle } from './SubstitutionToggle';

type Props = { line: PickLine; onPicked: (quantity: number) => void };

export function PickListRow({ line, onPicked }: Props) {
  const [quantity, setQuantity] = useState(line.quantity);
  const [allowSubstitute, setAllowSubstitute] = useState(true);

  return (
    <View style={styles.row}>
      <ProductThumb uri={line.imageUrl} />
      <View style={styles.body}>
        <Text style={styles.name}>{line.name}</Text>
        <QtyStepper value={quantity} max={line.quantity} onChange={setQuantity} />
        <SubstitutionToggle value={allowSubstitute} onChange={setAllowSubstitute} />
        {line.looseWeight ? <WeighButton onWeighed={(grams) => onPicked(grams)} /> : null}
      </View>
      <TouchableOpacity
        accessibilityLabel={`Mark ${line.name} picked`}
        onPress={() => onPicked(quantity)}
        style={styles.done}
      >
        <Text style={styles.doneLabel}>Picked</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 8 },
  body: { flex: 1, gap: 4 },
  name: { fontSize: 16, color: colors.text },
  done: { minWidth: 88, minHeight: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.brand },
  doneLabel: { fontSize: 15, fontWeight: '700', color: colors.onBrand },
});
