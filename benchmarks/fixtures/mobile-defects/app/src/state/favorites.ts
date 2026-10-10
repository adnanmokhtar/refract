import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { apiFetch } from '../api/http';

export function useFavorites(productId: string) {
  const queryClient = useQueryClient();
  const favorites = useQuery({ queryKey: ['favorites'], queryFn: () => apiFetch<string[]>('/me/favorites') });
  const mutation = useMutation({
    mutationFn: (next: boolean) =>
      apiFetch(`/me/favorites/${productId}`, { method: next ? 'POST' : 'DELETE' }),
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['favorites'] }),
  });
  const isFavorite = favorites.data?.includes(productId) ?? false;
  return { isFavorite, toggle: () => mutation.mutate(!isFavorite) };
}
