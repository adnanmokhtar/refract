import { Ionicons } from '@expo/vector-icons';
import { Pressable, StyleSheet } from 'react-native';

import { useFavorites } from '../state/favorites';
import { colors } from '../theme/colors';

type Props = { productId: string };

export function FavoriteButton({ productId }: Props) {
  const { isFavorite, toggle } = useFavorites(productId);

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected: isFavorite }}
      onPress={toggle}
      style={styles.button}
    >
      <Ionicons name={isFavorite ? 'heart' : 'heart-outline'} size={22} color={colors.accent} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' },
});
