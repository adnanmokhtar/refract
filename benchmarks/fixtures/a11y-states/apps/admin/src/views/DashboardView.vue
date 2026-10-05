<script setup lang="ts">
import { computed } from 'vue';
import { useQueries } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';
import KpiCounter from '../components/KpiCounter.vue';
import SignupsLine from '../components/charts/SignupsLine.vue';
import LatencyLine from '../components/charts/LatencyLine.vue';

const { t } = useI18n();

const results = useQueries({
  queries: [
    { queryKey: ['kpi', 'revenue'], queryFn: async () => (await api.get<{ total: number }>('/kpi/revenue')).data },
    { queryKey: ['kpi', 'signups'], queryFn: async () => (await api.get<{ week: string; count: number | null }[]>('/kpi/signups')).data },
    { queryKey: ['kpi', 'latency'], queryFn: async () => (await api.get<{ hour: string; p95: number }[]>('/kpi/latency')).data },
  ],
});

const anyPending = computed(() => results.value.some((r) => r.isPending));
const anyError = computed(() => results.value.some((r) => r.isError));
const refetchAll = () => results.value.forEach((r) => r.refetch());
</script>

<template>
  <section>
    <h1>{{ t('dashboard.title') }}</h1>
    <div v-if="anyPending" class="skeleton" aria-busy="true"></div>
    <div v-else-if="anyError" role="alert" class="dashboard-error">
      <p>{{ t('common.error') }}</p>
      <button class="btn" type="button" @click="refetchAll">{{ t('common.retry') }}</button>
    </div>
    <div v-else class="dashboard-grid">
      <article class="card">
        <h2>{{ t('dashboard.revenue') }}</h2>
        <KpiCounter :value="results[0].data?.total ?? 0" />
      </article>
      <article class="card">
        <h2>{{ t('dashboard.signups') }}</h2>
        <SignupsLine :points="results[1].data ?? []" />
      </article>
      <article class="card">
        <h2>{{ t('dashboard.latency') }}</h2>
        <LatencyLine :points="results[2].data ?? []" />
      </article>
    </div>
  </section>
</template>

<style scoped>
.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(18rem, 1fr));
  gap: var(--space-4);
}
</style>
