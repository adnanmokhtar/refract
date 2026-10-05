<script setup lang="ts">
import { computed } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useI18n } from 'vue-i18n';
import { api, type AuditEntry } from '../lib/api';

// Only the "owner" role may read the audit log; the API answers 403 for support and finance staff.
const { t, d } = useI18n();

const { data, isPending, isError } = useQuery({
  queryKey: ['audit-log'],
  queryFn: async () => (await api.get<AuditEntry[]>('/audit-log')).data,
});

const entries = computed(() => (isError.value ? [] : data.value ?? []));
</script>

<template>
  <section>
    <h1>{{ t('audit.title') }}</h1>
    <div v-if="isPending" class="skeleton" aria-busy="true"></div>
    <p v-else-if="entries.length === 0" class="audit-none">{{ t('audit.none') }}</p>
    <ol v-else class="audit-list">
      <li v-for="entry in entries" :key="entry.id">
        <time :datetime="entry.at">{{ d(new Date(entry.at), 'long') }}</time>
        — {{ entry.actor }}: {{ entry.action }}
      </li>
    </ol>
  </section>
</template>
