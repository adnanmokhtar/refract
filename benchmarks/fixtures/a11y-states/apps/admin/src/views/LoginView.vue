<script setup lang="ts">
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';
import { useSession } from '../stores/session';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const session = useSession();

const email = ref('');
const password = ref('');
const submitting = ref(false);
const failed = ref(false);

async function signIn() {
  submitting.value = true;
  failed.value = false;
  try {
    const { data } = await api.post('/auth/sign-in', { email: email.value, password: password.value });
    session.setUser(data.user);
    const returnTo = typeof route.query.returnTo === 'string' && route.query.returnTo.startsWith('/') ? route.query.returnTo : '/orders';
    await router.replace(returnTo);
  } catch {
    failed.value = true;
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <form class="login" @submit.prevent="signIn">
    <h1>{{ t('login.submit') }}</h1>
    <label for="login-email">{{ t('login.email') }}</label>
    <input id="login-email" v-model="email" type="email" autocomplete="username" required />
    <label for="login-password">{{ t('login.password') }}</label>
    <input id="login-password" v-model="password" type="password" autocomplete="off" required />
    <p v-if="failed" role="alert" class="login-error">{{ t('common.error') }}</p>
    <button class="btn" type="submit" :disabled="submitting">{{ t('login.submit') }}</button>
  </form>
</template>

<style scoped>
.login {
  display: grid;
  gap: var(--space-2);
  max-width: 22rem;
  margin: var(--space-6) auto;
}
</style>
