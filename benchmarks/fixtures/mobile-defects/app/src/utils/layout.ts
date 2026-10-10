import type { StyleProp, ViewStyle } from 'react-native';
import flattenStyle from 'react-native/Libraries/StyleSheet/flattenStyle';

/** The horizontal padding a card ends up with after its style array is merged, for aligning the sticky footer. */
export function horizontalInset(style: StyleProp<ViewStyle>): number {
  const flat = flattenStyle(style) ?? {};
  const value = flat.paddingHorizontal ?? flat.padding ?? 0;
  return typeof value === 'number' ? value : 0;
}
