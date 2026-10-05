<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type Invoice } from '../lib/api';

const { t, d, n } = useI18n();

const { data: invoices, isPending, isError, refetch } = useQuery({
  queryKey: ['invoices', 'open'],
  queryFn: async () => (await api.get<Invoice[]>('/invoices', { params: { state: 'open' } })).data,
});
</script>

<template>
  <section>
    <h1>{{ t('invoices.title') }}</h1>
    <div v-if="isPending" class="skeleton" aria-busy="true"></div>
    <div v-if="isError" role="alert">
      <p>{{ t('common.error') }}</p>
      <button class="btn" type="button" @click="refetch()">{{ t('common.retry') }}</button>
    </div>
    <table v-if="invoices" class="data-table">
      <thead>
        <tr>
          <th scope="col">#</th>
          <th scope="col">{{ t('orders.amount') }}</th>
          <th scope="col">{{ t('invoices.due') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="invoice in invoices" :key="invoice.id">
          <td>{{ invoice.number }}</td>
          <td>{{ n(invoice.amount / 100, 'currency') }}</td>
          <td>{{ d(new Date(invoice.dueAt), 'short') }}</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
