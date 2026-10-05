<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

const { t } = useI18n();
const notesUrl = ref<string | null>(null);

// "What's new" for dispatchers: the release-notes service returns an embed URL when there is something unread.
onMounted(async () => {
  const { data } = await api.get<{ embedUrl: string | null }>('/release-notes/unread');
  notesUrl.value = data.embedUrl;
});
</script>

<template>
  <section class="whats-new">
    <iframe v-if="notesUrl" :src="notesUrl" :title="t('help.title')"></iframe>
  </section>
</template>
