import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { router } from 'expo-router';
import { FlatList, StyleSheet } from 'react-native';

import { apiFetch } from '../api/http';
import { SavedAddressRow } from '../components/SavedAddressRow';
import type { Address } from '../state/addresses';
import { colors } from '../theme/colors';

export default function AddressesScreen() {
  const queryClient = useQueryClient();
  const addresses = useQuery({ queryKey: ['addresses'], queryFn: () => apiFetch<Address[]>('/me/addresses') });
  const remove = useMutation({
    mutationFn: (id: string) => apiFetch(`/me/addresses/${id}`, { method: 'DELETE' }),
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['addresses'] }),
  });

  return (
    <FlatList
      style={styles.list}
      data={addresses.data ?? []}
      keyExtractor={(address) => address.id}
      renderItem={({ item }) => (
        <SavedAddressRow
          address={item}
          onDelete={(id) => remove.mutate(id)}
          onEdit={(id) => router.push(`/addresses/${id}`)}
        />
      )}
    />
  );
}

const styles = StyleSheet.create({
  list: { flex: 1, backgroundColor: colors.surface },
});
