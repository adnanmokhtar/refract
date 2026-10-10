import { router } from 'expo-router';
import { FlatList, Pressable, StyleSheet, Text, View } from 'react-native';

import { CartLineSwipe } from '../components/CartLineSwipe';
import { useBasket } from '../state/BasketProvider';
import { colors, type } from '../theme/colors';

export default function BasketScreen() {
  const { lines, remove } = useBasket();

  return (
    <View style={styles.screen}>
      <FlatList
        data={lines}
        keyExtractor={(line) => line.id}
        renderItem={({ item }) => <CartLineSwipe line={item} onRemove={remove} />}
        ListEmptyComponent={<Text style={styles.empty}>Your basket is empty.</Text>}
      />
      <Pressable accessibilityRole="button" onPress={() => router.push('/checkout')} style={styles.cta}>
        <Text style={styles.ctaLabel}>Go to checkout</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.surface },
  empty: { padding: 24, fontSize: type.body, color: colors.textMuted, textAlign: 'center' },
  cta: { margin: 16, minHeight: 52, borderRadius: 26, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.brand },
  ctaLabel: { fontSize: type.body, fontWeight: '700', color: colors.onBrand },
});
