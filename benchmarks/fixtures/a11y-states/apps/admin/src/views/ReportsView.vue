<script setup lang="ts">
import { ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';
import RevenueBars from '../components/charts/RevenueBars.vue';

type Report = { month: string; revenue: number; target: number }[];

const { t } = useI18n();
const year = ref(new Date().getFullYear());

const { data, isPending, isError } = useQuery({
  queryKey: ['reports', 'revenue', year],
  queryFn: async () => (await api.get<Report>('/reports/revenue', { params: { year: year.value } })).data,
});
</script>

<template>
  <section>
    <h1>{{ t('reports.title') }}</h1>
    <div v-if="isPending" class="skeleton" aria-busy="true"></div>
    <p v-else-if="isError" class="report-error">{{ t('reports.failed') }}</p>
    <RevenueBars v-else-if="data && data.length > 0" :points="data" />
    <p v-else>—</p>
  </section>
</template>

<style scoped>
.report-error {
  color: var(--danger);
}
</style>
