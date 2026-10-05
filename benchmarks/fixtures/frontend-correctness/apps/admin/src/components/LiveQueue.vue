<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

const { t } = useI18n();
const waiting = ref(0);
let timer: ReturnType<typeof setInterval> | undefined;

onMounted(() => {
  timer = setInterval(async () => {
    const { data } = await api.get<{ waiting: number }>('/queue/stats');
    waiting.value = data.waiting;
  }, 10_000);
});

onUnmounted(() => clearInterval(timer));
</script>

<template>
  <p class="live-queue">{{ t('dispatch.waiting', { n: waiting }) }}</p>
</template>
