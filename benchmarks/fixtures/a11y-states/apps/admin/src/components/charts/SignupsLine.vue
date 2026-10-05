<script setup lang="ts">
import { computed } from 'vue';
import { Line } from 'vue-chartjs';
import { CategoryScale, Chart as ChartJS, LineElement, LinearScale, PointElement, Tooltip } from 'chart.js';
import { cssVar } from '../../lib/theme';

ChartJS.register(CategoryScale, LineElement, LinearScale, PointElement, Tooltip);

// Weekly sign-ups. A week is null when the analytics export failed for it.
const props = defineProps<{ points: { week: string; count: number | null }[] }>();

const chartData = computed(() => ({
  labels: props.points.map((p) => p.week),
  datasets: [
    {
      label: 'Sign-ups',
      data: props.points.map((p) => p.count),
      borderColor: cssVar('--brand'),
      spanGaps: true,
      tension: 0.3,
    },
  ],
}));

const options = {
  responsive: true,
  scales: { y: { beginAtZero: true, title: { display: true, text: 'Sign-ups per week' } } },
};
</script>

<template>
  <Line :data="chartData" :options="options" aria-label="Weekly sign-ups" role="img" />
</template>
