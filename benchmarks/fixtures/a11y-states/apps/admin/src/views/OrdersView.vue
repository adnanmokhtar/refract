<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type AdminOrder } from '../lib/api';
import StatusFilter from '../components/StatusFilter.vue';
import FilterChip from '../components/FilterChip.vue';
import RefundDrawer from '../components/RefundDrawer.vue';
import Pagination from '../components/Pagination.vue';
import StatusPill from '../components/StatusPill.vue';

const { t } = useI18n();
const page = ref(1);
const status = ref<string | null>(null);
const selectedId = ref<string | null>(null);

const { data, isPending, isError, refetch } = useQuery({
  queryKey: ['orders', page, status],
  queryFn: async () =>
    (await api.get<{ items: AdminOrder[]; pages: number }>('/orders', { params: { page: page.value, status: status.value } })).data,
});

const orders = computed(() => data.value?.items ?? []);
const selected = computed(() => orders.value.find((o) => o.id === selectedId.value) ?? null);

function select(id: string) {
  selectedId.value = id;
}
</script>

<template>
  <section>
    <h1>{{ t('orders.title') }}</h1>
    <div class="toolbar">
      <StatusFilter v-model="status" />
      <FilterChip v-if="status" :label="status" @remove="status = null" />
    </div>

    <div v-if="isPending" class="skeleton" aria-busy="true"></div>
    <div v-else-if="isError" role="alert">
      <p>{{ t('common.error') }}</p>
      <button class="btn" type="button" @click="refetch()">{{ t('common.retry') }}</button>
    </div>
    <p v-else-if="orders.length === 0">—</p>
    <ul v-else class="order-list">
      <li v-for="o in orders" :key="o.id" class="card order-row" @click="select(o.id)">
        <span class="order-number">{{ o.number }}</span>
        <span>{{ o.customer }}</span>
        <StatusPill :status="o.status" />
      </li>
    </ul>

    <Pagination v-model="page" :pages="data?.pages ?? 1" />
    <RefundDrawer v-if="selected" :order="selected" @close="selectedId = null" />
  </section>
</template>

<style scoped>
.toolbar {
  display: flex;
  gap: var(--space-3);
  margin-block: var(--space-4);
}

.order-list {
  list-style: none;
  padding: 0;
  display: grid;
  gap: var(--space-2);
}

.order-row {
  display: grid;
  grid-template-columns: 8rem 1fr auto;
  align-items: center;
  cursor: pointer;
}
</style>
