<script setup lang="ts">
import { computed, ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type Customer } from '../lib/api';

const { t } = useI18n();
const query = ref('');

const { data, isError, refetch } = useQuery({
  queryKey: ['customers'],
  queryFn: async () => (await api.get<Customer[]>('/customers')).data,
});

const visible = computed(() => {
  const q = query.value.trim().toLowerCase();
  const all = data.value ?? [];
  return q ? all.filter((c) => c.name.toLowerCase().includes(q) || c.email.includes(q)) : all;
});
</script>

<template>
  <section>
    <h1>{{ t('customers.title') }}</h1>
    <input v-model="query" type="search" placeholder="Filter customers" class="filter" />

    <div v-if="isError" role="alert">
      <p>{{ t('common.error') }}</p>
      <button class="btn" type="button" @click="refetch()">{{ t('common.retry') }}</button>
    </div>
    <table v-else class="data-table">
      <thead>
        <tr>
          <th scope="col">Name</th>
          <th scope="col">Email</th>
          <th scope="col">Orders</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="c in visible" :key="c.id">
          <td>{{ c.name }}</td>
          <td>{{ c.email }}</td>
          <td>{{ c.orders }}</td>
        </tr>
        <tr v-if="visible.length === 0">
          <td colspan="3">—</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>

<style scoped>
.filter {
  width: 100%;
  max-width: 24rem;
  margin-block: var(--space-4);
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--border);
  border-radius: var(--radius);
}
</style>
