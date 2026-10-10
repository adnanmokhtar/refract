import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { logout } from '../auth/logout';
import { colors, type } from '../theme/colors';

export default function AccountScreen() {
  return (
    <View style={styles.screen}>
      <Pressable accessibilityRole="button" onPress={() => router.push('/orders')} style={styles.row}>
        <Text style={styles.label}>Your orders</Text>
      </Pressable>
      <Pressable accessibilityRole="button" onPress={() => router.push('/addresses')} style={styles.row}>
        <Text style={styles.label}>Saved addresses</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        onPress={async () => {
          await logout();
          router.replace('/onboarding');
        }}
        style={styles.row}
      >
        <Text style={[styles.label, styles.danger]}>Sign out</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.surface },
  row: { minHeight: 56, justifyContent: 'center', paddingHorizontal: 16 },
  label: { fontSize: type.body, color: colors.text },
  danger: { color: colors.danger },
});
