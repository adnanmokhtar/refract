<script setup lang="ts">
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

type Customer = { id: string; name: string; postcode: string };

const { t } = useI18n();
const q = ref('');
const results = ref<Customer[]>([]);

watch(q, async (value) => {
  if (value.trim().length < 2) {
    results.value = [];
    return;
  }
  const { data } = await api.get<Customer[]>('/customers', { params: { q: value } });
  results.value = data;
});
</script>

<template>
  <section>
    <h1>{{ t('customers.title') }}</h1>
    <label for="customer-q">{{ t('customers.search') }}</label>
    <input id="customer-q" v-model="q" type="search" />
    <ul>
      <li v-for="c in results" :key="c.id">{{ c.name }} · {{ c.postcode }}</li>
    </ul>
  </section>
</template>
