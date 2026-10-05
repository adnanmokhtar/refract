<script setup lang="ts">
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import { BarElement, CategoryScale, Chart as ChartJS, LinearScale, Tooltip } from 'chart.js';

ChartJS.register(BarElement, CategoryScale, LinearScale, Tooltip);

const props = defineProps<{ points: { month: string; revenue: number; target: number }[] }>();

// Each month's revenue, coloured by whether it hit the monthly target.
const chartData = computed(() => ({
  labels: props.points.map((p) => p.month),
  datasets: [
    {
      label: 'Revenue',
      data: props.points.map((p) => p.revenue / 100),
      backgroundColor: props.points.map((p) => (p.revenue >= p.target ? '#22c55e' : '#ef4444')),
    },
  ],
}));

const options = {
  responsive: true,
  plugins: { legend: { display: false } },
  scales: {
    y: {
      beginAtZero: false,
      ticks: { callback: (v: string | number) => `${Number(v) / 1000}k` },
    },
  },
};
</script>

<template>
  <Bar :data="chartData" :options="options" aria-label="Monthly revenue" role="img" />
</template>
