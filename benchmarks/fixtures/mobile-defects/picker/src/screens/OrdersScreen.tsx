import { useNavigation } from '@react-navigation/native';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';

import { api } from '../api/client';
import { colors } from '../theme/colors';

type StoreOrder = { id: string; customer: string; slot: string; lineCount: number; status: string };

/** Every order the store has to pick today, oldest slot first. A Saturday runs to several hundred. */
export function OrdersScreen() {
  const navigation = useNavigation();
  const [orders, setOrders] = useState<StoreOrder[]>([]);

  useEffect(() => {
    let cancelled = false;
    api.get<StoreOrder[]>('/store/orders/today').then(
      ({ data }) => !cancelled && setOrders(data),
      () => !cancelled && setOrders([]),
    );
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <ScrollView contentContainerStyle={styles.list}>
      {orders.map((order) => (
        <Pressable
          key={order.id}
          accessibilityRole="button"
          onPress={() => navigation.navigate('PickList' as never, { id: order.id } as never)}
          style={styles.card}
        >
          <Text style={styles.slot}>{order.slot}</Text>
          <Text style={styles.customer}>{order.customer}</Text>
          <Text style={styles.meta}>
            {order.lineCount} lines · {order.status}
          </Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  list: { padding: 12, gap: 8 },
  card: { minHeight: 72, padding: 12, borderRadius: 12, backgroundColor: colors.surfaceAlt },
  slot: { fontSize: 13, fontWeight: '700', color: colors.brand },
  customer: { fontSize: 16, color: colors.text },
  meta: { fontSize: 13, color: colors.textMuted },
});
