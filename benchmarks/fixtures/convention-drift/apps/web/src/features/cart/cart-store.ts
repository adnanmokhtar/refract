import { type PayloadAction, configureStore, createSlice } from '@reduxjs/toolkit';
import { type TypedUseSelectorHook, useDispatch, useSelector } from 'react-redux';

export type CartItem = { sku: string; name: string; quantity: number; priceMinor: number };

const cart = createSlice({
  name: 'cart',
  initialState: { items: [] as CartItem[], currency: 'EUR' },
  reducers: {
    add(state, action: PayloadAction<CartItem>) {
      state.items.push(action.payload);
    },
    drop(state, action: PayloadAction<string>) {
      state.items = state.items.filter((i) => i.sku !== action.payload);
    },
  },
});

export const { add, drop } = cart.actions;
export const store = configureStore({ reducer: { cart: cart.reducer } });
export type RootState = ReturnType<typeof store.getState>;
export const useAppDispatch: () => typeof store.dispatch = useDispatch;
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
