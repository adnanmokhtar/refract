import { useNavigation } from '@react-navigation/native';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { useSignIn } from '../auth/useSignIn';
import { colors } from '../theme/colors';

export function SignInScreen() {
  const navigation = useNavigation();
  const signIn = useSignIn(navigation);
  const [badgeId, setBadgeId] = useState('');
  const [pin, setPin] = useState('');

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Sign in to picking</Text>
      <TextInput accessibilityLabel="Badge number" value={badgeId} onChangeText={setBadgeId} style={styles.input} />
      <TextInput
        accessibilityLabel="PIN"
        keyboardType="number-pad"
        secureTextEntry
        value={pin}
        onChangeText={setPin}
        style={styles.input}
      />
      <Pressable accessibilityRole="button" onPress={() => signIn(badgeId, pin)} style={styles.cta}>
        <Text style={styles.ctaLabel}>Sign in</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 24, gap: 12, justifyContent: 'center', backgroundColor: colors.surface },
  title: { fontSize: 22, fontWeight: '700', color: colors.text },
  input: { minHeight: 48, borderRadius: 8, paddingHorizontal: 12, backgroundColor: colors.surfaceAlt },
  cta: { minHeight: 52, borderRadius: 26, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.brand },
  ctaLabel: { fontSize: 16, fontWeight: '700', color: colors.onBrand },
});
