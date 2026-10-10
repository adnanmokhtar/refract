import { useInfiniteQuery } from '@tanstack/react-query';
import { router } from 'expo-router';
import { FlatList, Pressable, StyleSheet, Text } from 'react-native';

import { apiFetch } from '../api/http';
import { colors, type } from '../theme/colors';
import { formatPrice } from '../utils/money';

type OrderSummary = { id: string; placedAt: string; totalCents: number; status: string };
type Page = { items: OrderSummary[]; next: string | null };

export default function OrderHistoryScreen() {
  const orders = useInfiniteQuery({
    queryKey: ['orders'],
    queryFn: ({ pageParam }) => apiFetch<Page>(`/me/orders?cursor=${pageParam ?? ''}`),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => last.next,
  });
  const items = orders.data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <FlatList
      data={items}
      renderItem={({ item }) => <OrderRow order={item} />}
      onEndReached={() => orders.hasNextPage && orders.fetchNextPage()}
      onEndReachedThreshold={0.5}
      contentContainerStyle={styles.list}
    />
  );
}

function OrderRow({ order }: { order: OrderSummary }) {
  return (
    <Pressable accessibilityRole="button" onPress={() => router.push(`/orders/${order.id}`)} style={styles.row}>
      <Text style={styles.date}>{new Date(order.placedAt).toLocaleDateString()}</Text>
      <Text style={styles.status}>{order.status}</Text>
      <Text style={styles.total}>{formatPrice(order.totalCents)}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  list: { paddingVertical: 8 },
  row: { minHeight: 56, flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16 },
  date: { flex: 1, fontSize: type.body, color: colors.text },
  status: { fontSize: type.caption, color: colors.textMuted },
  total: { fontSize: type.body, fontWeight: '600', color: colors.text },
});
