<script setup lang="ts">
import { RouterLink } from 'vue-router';
import { useMutation, useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type Picker } from '../lib/api';

const { t } = useI18n();
const { data: pickers, isPending } = useQuery({
  queryKey: ['pickers'],
  queryFn: async () => (await api.get<Picker[]>('/pickers')).data,
});

const deactivate = useMutation({
  mutationFn: (id: string) => api.patch(`/pickers/${id}`, { active: false }),
});
</script>

<template>
  <section>
    <h1>{{ t('pickers.title') }}</h1>
    <p v-if="isPending" aria-busy="true">{{ t('common.loading') }}</p>
    <ul v-else>
      <li v-for="p in pickers" :key="p.id">
        <RouterLink :to="`/pickers/${p.id}`">{{ p.name }}</RouterLink>
        <button type="button" class="btn" :disabled="!p.active || deactivate.isPending.value" @click="deactivate.mutate(p.id)">
          {{ t('pickers.deactivate') }}
        </button>
      </li>
    </ul>
  </section>
</template>
