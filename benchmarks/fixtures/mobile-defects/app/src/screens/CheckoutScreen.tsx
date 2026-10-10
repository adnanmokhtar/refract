import { useEffect, useState } from 'react';
import { Keyboard, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { useBasket } from '../state/BasketProvider';
import { colors, type } from '../theme/colors';
import { formatPrice } from '../utils/money';
import { sendOrder } from '../offline/sendOrder';
import { createPaymentSession } from '../payments/paymentSession';

export default function CheckoutScreen() {
  const { lines } = useBasket();
  const [note, setNote] = useState('');
  const [keyboardOpen, setKeyboardOpen] = useState(false);
  const [placing, setPlacing] = useState(false);

  useEffect(() => {
    Keyboard.addListener('keyboardDidShow', () => setKeyboardOpen(true));
    Keyboard.addListener('keyboardDidHide', () => setKeyboardOpen(false));
  }, []);

  const total = lines.reduce((sum, line) => sum + line.unitCents * line.quantity, 0);

  async function placeOrder() {
    setPlacing(true);
    try {
      const order = await sendOrder({
        storeId: 'nearest',
        slotId: 'next',
        addressId: 'default',
        lines: lines.map((line) => ({ productId: line.productId, quantity: line.quantity })),
        substitutions: 'ask',
      });
      await createPaymentSession(order.id);
    } finally {
      setPlacing(false);
    }
  }

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Checkout</Text>
      <Text style={styles.summary}>
        {lines.length} items · {formatPrice(total)}
      </Text>
      <TextInput
        accessibilityLabel="Note for your picker"
        placeholder="Anything we should know?"
        value={note}
        onChangeText={setNote}
        multiline
        style={styles.note}
      />
      {keyboardOpen ? null : (
        <Pressable accessibilityRole="button" disabled={placing} onPress={placeOrder} style={styles.cta}>
          <Text style={styles.ctaLabel}>{placing ? 'Placing…' : 'Place order'}</Text>
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 16, gap: 16, backgroundColor: colors.surface },
  title: { fontSize: type.title, fontWeight: '700', color: colors.text },
  summary: { fontSize: type.body, color: colors.textMuted },
  note: { minHeight: 96, borderRadius: 8, padding: 12, backgroundColor: colors.surfaceAlt, fontSize: type.body },
  cta: { minHeight: 52, borderRadius: 26, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.brand },
  ctaLabel: { fontSize: type.body, fontWeight: '700', color: colors.onBrand },
});
