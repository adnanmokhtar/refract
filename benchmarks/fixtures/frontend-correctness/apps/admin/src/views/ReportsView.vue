<script setup lang="ts">
import { onMounted, ref } from 'vue';
import axios from 'axios';
import { useI18n } from 'vue-i18n';

type Row = { day: string; orders: number; late: number };

const { t } = useI18n();
const rows = ref<Row[]>([]);
const failed = ref(false);

onMounted(async () => {
  try {
    const { data } = await axios.get<Row[]>('/api/admin/reports/weekly');
    rows.value = data;
  } catch {
    failed.value = true;
  }
});
</script>

<template>
  <section>
    <h1>{{ t('reports.title') }}</h1>
    <p v-if="failed" role="alert">{{ t('common.error') }}</p>
    <table v-else class="table">
      <thead>
        <tr>
          <th scope="col">{{ t('reports.day') }}</th>
          <th scope="col">{{ t('reports.orders') }}</th>
          <th scope="col">{{ t('reports.late') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in rows" :key="r.day">
          <td>{{ r.day }}</td>
          <td>{{ r.orders }}</td>
          <td>{{ r.late }}</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
