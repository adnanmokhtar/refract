import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { signUp } from '../account/register';
import { startAttribution } from '../analytics/tracking';
import { registerForPush } from '../push/registerPush';
import { colors, type } from '../theme/colors';

export default function OnboardingScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [firstName, setFirstName] = useState('');

  async function createAccount() {
    await signUp({ email, password, firstName, marketingOptIn: false });
    await startAttribution();
    await registerForPush(() => undefined);
    router.replace('/');
  }

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Create your account</Text>
      <TextInput accessibilityLabel="First name" value={firstName} onChangeText={setFirstName} style={styles.input} />
      <TextInput accessibilityLabel="Email" autoComplete="email" value={email} onChangeText={setEmail} style={styles.input} />
      <TextInput
        accessibilityLabel="Password"
        autoComplete="new-password"
        secureTextEntry
        value={password}
        onChangeText={setPassword}
        style={styles.input}
      />
      <Pressable accessibilityRole="button" onPress={createAccount} style={styles.cta}>
        <Text style={styles.ctaLabel}>Create account</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 24, gap: 12, backgroundColor: colors.surface },
  title: { fontSize: type.title, fontWeight: '700', color: colors.text },
  input: { minHeight: 48, borderRadius: 8, paddingHorizontal: 12, backgroundColor: colors.surfaceAlt, fontSize: type.body },
  cta: { minHeight: 52, borderRadius: 26, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.brand },
  ctaLabel: { fontSize: type.body, fontWeight: '700', color: colors.onBrand },
});
