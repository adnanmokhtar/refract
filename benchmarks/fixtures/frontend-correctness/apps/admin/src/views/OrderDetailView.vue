<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type DispatchOrder } from '../lib/api';
import PriorityToggle from '../components/PriorityToggle.vue';

const { t } = useI18n();
const route = useRoute();
const orderId = computed(() => Number(route.params.id));

const { data: order, isPending, isError } = useQuery({
  queryKey: ['order', orderId],
  queryFn: async () => (await api.get<DispatchOrder & { priority: boolean }>(`/orders/${orderId.value}`)).data,
});
</script>

<template>
  <section>
    <p v-if="isPending" aria-busy="true">{{ t('common.loading') }}</p>
    <p v-else-if="isError" role="alert">{{ t('common.error') }}</p>
    <template v-else-if="order">
      <h1>{{ order.number }}</h1>
      <p>{{ order.customer }}</p>
      <PriorityToggle :order-id="order.id" :priority="order.priority" />
    </template>
  </section>
</template>
