<script setup lang="ts">
import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

const props = defineProps<{ orderId: string; priority: boolean }>();
const { t } = useI18n();
const qc = useQueryClient();

const toggle = useMutation({
  mutationFn: (next: boolean) => api.patch(`/orders/${props.orderId}`, { priority: next }),
  onMutate: async (next: boolean) => {
    await qc.cancelQueries({ queryKey: ['order'] });
    qc.setQueriesData({ queryKey: ['order'] }, (old: { priority: boolean } | undefined) => (old ? { ...old, priority: next } : old));
  },
  onSettled: () => qc.invalidateQueries({ queryKey: ['order'] }),
});
</script>

<template>
  <label class="toggle">
    <input type="checkbox" :checked="props.priority" @change="toggle.mutate(!props.priority)" />
    {{ t('orders.priority') }}
  </label>
</template>
