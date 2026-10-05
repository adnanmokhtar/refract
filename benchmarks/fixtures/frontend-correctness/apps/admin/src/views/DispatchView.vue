<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type DispatchOrder } from '../lib/api';
import { useDispatchStore } from '../stores/dispatch';
import { usePickersStore } from '../stores/pickers';
import OrderCard from '../components/OrderCard.vue';
import LiveQueue from '../components/LiveQueue.vue';
import QueueSummary from '../components/QueueSummary.vue';
import ColumnResizer from '../components/ColumnResizer.vue';

const { t } = useI18n();
const router = useRouter();
const store = useDispatchStore();
const pickers = usePickersStore();
const { orders, selected } = useDispatchStore();

const { isPending, isError, refetch } = useQuery({
  queryKey: ['dispatch', 'orders'],
  queryFn: async () => {
    const { data } = await api.get<DispatchOrder[]>('/dispatch/orders');
    store.setOrders(data);
    await pickers.loadMany([...new Set(data.flatMap((o) => (o.pickerId ? [o.pickerId] : [])))]);
    return data;
  },
});
</script>

<template>
  <section>
    <h1>{{ t('dispatch.title') }}</h1>
    <QueueSummary :count="orders.length" />
    <LiveQueue />
    <ColumnResizer />
    <p v-if="isPending" aria-busy="true">{{ t('common.loading') }}</p>
    <p v-else-if="isError" role="alert">
      {{ t('common.error') }} <button type="button" class="btn" @click="refetch()">{{ t('common.retry') }}</button>
    </p>
    <div v-else class="board">
      <div
        v-for="order in orders"
        :key="order.id"
        class="card"
        :class="{ selected: selected === order.id }"
        @click="router.push(`/orders/${order.id}`)"
      >
        <OrderCard :order="order" />
      </div>
    </div>
  </section>
</template>
