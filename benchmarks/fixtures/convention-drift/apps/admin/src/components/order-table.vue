<script setup lang="ts">
import { formatMoney } from '@acme/format';
import type { AdminOrder } from '../stores/orders-store';
import { formatDate } from '../utils/format-date';

defineProps<{ orders: AdminOrder[] }>();
</script>

<template>
  <table class="w-full">
    <tbody>
      <tr v-for="o in orders" :key="o.id" class="border-b border-muted">
        <td class="p-2">{{ o.reference }}</td>
        <td class="p-2">{{ formatDate(o.createdAt) }}</td>
        <td class="p-2 text-right">{{ formatMoney(o.totalMinor, o.currency) }}</td>
      </tr>
    </tbody>
  </table>
</template>
