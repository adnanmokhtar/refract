import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';

import { colors, type } from '../theme/colors';

export type SortKey = 'relevance' | 'price-asc' | 'price-desc' | 'newest' | 'rating' | 'distance';

const SORT_OPTIONS: ReadonlyArray<{ id: SortKey; label: string }> = [
  { id: 'relevance', label: 'Most relevant' },
  { id: 'price-asc', label: 'Price: low to high' },
  { id: 'price-desc', label: 'Price: high to low' },
  { id: 'newest', label: 'Newest' },
  { id: 'rating', label: 'Best rated' },
  { id: 'distance', label: 'Nearest store' },
];

type Props = { value: SortKey; onChange: (key: SortKey) => void };

export function SortSheet({ value, onChange }: Props) {
  return (
    <ScrollView contentContainerStyle={styles.list}>
      {SORT_OPTIONS.map((option) => (
        <Pressable
          key={option.id}
          accessibilityRole="radio"
          accessibilityState={{ checked: option.id === value }}
          onPress={() => onChange(option.id)}
          style={styles.option}
        >
          <Text style={styles.label}>{option.label}</Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  list: { paddingVertical: 8 },
  option: { minHeight: 48, justifyContent: 'center', paddingHorizontal: 16 },
  label: { fontSize: type.body, color: colors.text },
});
