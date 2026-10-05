<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { z } from 'zod';
import { api, type Picker } from '../lib/api';

const { t } = useI18n();
const route = useRoute();
const parsed = computed(() => z.string().regex(/^p_[a-z0-9]{8}$/).safeParse(route.params.id));

const { data: picker, isPending } = useQuery({
  queryKey: ['picker', computed(() => (parsed.value.success ? parsed.value.data : null))],
  queryFn: async () => (await api.get<Picker>(`/pickers/${parsed.value.data}`)).data,
  enabled: computed(() => parsed.value.success),
});
</script>

<template>
  <section>
    <p v-if="!parsed.success" role="alert">{{ t('pickers.notFound') }}</p>
    <p v-else-if="isPending" aria-busy="true">{{ t('common.loading') }}</p>
    <h1 v-else>{{ picker?.name }}</h1>
  </section>
</template>
