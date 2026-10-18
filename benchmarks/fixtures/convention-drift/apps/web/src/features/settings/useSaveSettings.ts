import { useMutation } from '@tanstack/react-query';
import { apiClient } from '@acme/http';

export function useSaveSettings() {
  return useMutation({ mutationFn: (body: { locale: 'en' | 'ar' }) => apiClient.put('me/settings', { json: body }).json() });
}
