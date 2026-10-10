import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { FlatList, StyleSheet, Text, View } from 'react-native';

import { apiFetch } from '../api/http';
import { BrandMark } from '../components/BrandMark';
import { FavoriteButton } from '../components/FavoriteButton';
import { PriceTag } from '../components/PriceTag';
import { SortSheet, type SortKey } from '../components/SortSheet';
import { colors, type } from '../theme/colors';

type Product = { id: string; name: string; priceCents: number; wasCents?: number; unit?: string };

export default function HomeScreen() {
  const [sort, setSort] = useState<SortKey>('relevance');
  const products = useQuery({
    queryKey: ['products', sort],
    queryFn: () => apiFetch<Product[]>(`/catalog/products?sort=${sort}`),
  });

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <BrandMark />
        <Text style={styles.title}>Fresh today</Text>
      </View>
      <SortSheet value={sort} onChange={setSort} />
      <FlatList
        data={products.data ?? []}
        keyExtractor={(product) => product.id}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <Text style={styles.name}>{item.name}</Text>
            <PriceTag cents={item.priceCents} wasCents={item.wasCents} unit={item.unit} />
            <FavoriteButton productId={item.id} />
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.surface },
  header: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16 },
  title: { fontSize: type.title, fontWeight: '700', color: colors.text },
  card: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 8 },
  name: { flex: 1, fontSize: type.body, color: colors.text },
});
