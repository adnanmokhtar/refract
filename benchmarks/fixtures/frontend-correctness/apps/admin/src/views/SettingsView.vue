<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';
import { useSession } from '../stores/session';

const { t } = useI18n();
const router = useRouter();
const session = useSession();
const cutoff = ref('14:00');

onMounted(() => {
  if (!session.user) router.push('/login');
});

async function save() {
  await api.patch('/settings', { sameDayCutoff: cutoff.value });
}
</script>

<template>
  <section>
    <h1>{{ t('settings.title') }}</h1>
    <form @submit.prevent="save">
      <label for="cutoff">{{ t('settings.cutoff') }}</label>
      <input id="cutoff" v-model="cutoff" type="time" />
      <button type="submit" class="btn">{{ t('common.save') }}</button>
    </form>
  </section>
</template>
