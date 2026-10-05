<script setup lang="ts">
import type { DispatchOrder } from '../lib/api';

defineProps<{ order: DispatchOrder }>();
const selected = defineModel<string[]>('selected', { required: true });
</script>

<template>
  <tr>
    <td><input v-model="selected" type="checkbox" :value="order.id" :aria-label="order.number" /></td>
    <td>{{ order.number }}</td>
    <td>{{ order.customer }}</td>
    <td class="eta">{{ new Date(order.eta).toLocaleTimeString() }}</td>
  </tr>
</template>
