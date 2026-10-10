import { StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';

/**
 * The "PG" monogram in the header. It is the logo, drawn as text so it stays crisp: the two letters must fit the
 * 48 pt badge at every system text size, and the badge itself carries the accessible name.
 */
export function BrandMark() {
  return (
    <View style={styles.badge} accessibilityRole="image" accessibilityLabel="Pantry Go">
      <Text style={styles.glyph} allowFontScaling={false} importantForAccessibility="no">
        PG
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: { width: 48, height: 48, borderRadius: 24, backgroundColor: colors.brand, alignItems: 'center', justifyContent: 'center' },
  glyph: { fontSize: 18, fontWeight: '700', color: colors.onBrand },
});
