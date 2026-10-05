import { useQuery } from '@tanstack/react-query';
import { accountApi } from './api';

export function useRecentlyViewed() {
  return useQuery({ queryKey: ['me', 'recently-viewed'], queryFn: accountApi.recentlyViewed });
}

export function useWishlist() {
  return useQuery({ queryKey: ['me', 'wishlist'], queryFn: accountApi.wishlist });
}

export function useOrders() {
  return useQuery({ queryKey: ['me', 'orders'], queryFn: accountApi.orders });
}

export function useStoreCredit() {
  return useQuery({ queryKey: ['me', 'store-credit'], queryFn: accountApi.storeCredit, retry: false });
}

export function useGiftCards() {
  return useQuery({ queryKey: ['me', 'gift-cards'], queryFn: accountApi.giftCards });
}

export function useSpend() {
  return useQuery({ queryKey: ['me', 'insights', 'spend'], queryFn: accountApi.spend });
}

export function usePointsTrend() {
  return useQuery({ queryKey: ['me', 'insights', 'points'], queryFn: accountApi.points });
}
