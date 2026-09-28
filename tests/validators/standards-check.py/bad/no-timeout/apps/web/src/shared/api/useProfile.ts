import { useQuery } from '@tanstack/react-query';
export const useProfile = () => useQuery({ queryKey: ['me'], queryFn: () => fetch('/api/me').then((r) => r.json()) });
