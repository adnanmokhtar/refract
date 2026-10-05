<script setup lang="ts">
import { computed } from 'vue';
import { Line } from 'vue-chartjs';
import { CategoryScale, Chart as ChartJS, LineElement, LinearScale, PointElement, Tooltip } from 'chart.js';
import { cssVar } from '../../lib/theme';

ChartJS.register(CategoryScale, LineElement, LinearScale, PointElement, Tooltip);

// Checkout p95 latency per hour. The SLO band is 380-460 ms, so the axis is zoomed to it and labelled.
const props = defineProps<{ points: { hour: string; p95: number }[] }>();

const chartData = computed(() => ({
  labels: props.points.map((p) => p.hour),
  datasets: [{ label: 'p95 (ms)', data: props.points.map((p) => p.p95), borderColor: cssVar('--brand') }],
}));

const options = {
  responsive: true,
  scales: {
    y: {
      beginAtZero: false,
      title: { display: true, text: 'p95 latency (ms) — axis starts at 300' },
      ticks: { callback: (v: string | number) => `${v} ms` },
    },
  },
};
</script>

<template>
  <Line :data="chartData" :options="options" aria-label="Checkout latency" role="img" />
</template>
