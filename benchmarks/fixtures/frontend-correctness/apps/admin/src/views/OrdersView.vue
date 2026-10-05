<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type DispatchOrder } from '../lib/api';
import DeliveryRow from '../components/DeliveryRow.vue';

const { t } = useI18n();
const selection = ref<string[]>([]);
const statuses = ['placed', 'picking', 'ready', 'out'] as const;
const status = ref<(typeof statuses)[number]>('placed');
const { data, isPending, isError, refetch } = useQuery({
  queryKey: ['orders', 'today', status],
  queryFn: async () => (await api.get<DispatchOrder[]>('/orders', { params: { day: 'today', status: status.value } })).data,
});
const orders = computed(() => data.value ?? []);

function exportCsv() {
  window.location.href = '/api/admin/orders/export.csv?day=today';
}
</script>

<template>
  <section>
    <header class="page-header">
      <h1>{{ t('orders.title') }}</h1>
      <button type="button" class="btn" :disabled="selection.length === 0">{{ t('orders.bulkRefund') }}</button>
      <button type="button" class="btn" @click="exportCsv">Export CSV</button>
    </header>
    <nav class="tabs" :aria-label="t('orders.status')">
      <button v-for="s in statuses" :key="s" type="button" class="tab" :aria-pressed="status === s" @click="status = s">
        {{ t(`status.${s}`) }}
      </button>
    </nav>
    <p v-if="isPending" aria-busy="true">{{ t('common.loading') }}</p>
    <p v-else-if="isError" role="alert">
      {{ t('common.error') }} <button type="button" class="btn" @click="refetch()">{{ t('common.retry') }}</button>
    </p>
    <p v-else-if="orders.length === 0">{{ t('orders.none') }}</p>
    <table v-else class="table">
      <tbody>
        <DeliveryRow v-for="o in orders" :key="o.id" :order="o" v-model:selected="selection" />
      </tbody>
    </table>
  </section>
</template>
