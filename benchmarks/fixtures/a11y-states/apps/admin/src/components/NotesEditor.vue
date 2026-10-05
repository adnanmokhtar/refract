<script setup lang="ts">
import { ref, watch } from 'vue';
import { api } from '../lib/api';

const props = defineProps<{ orderId: string; initial?: string }>();
const text = ref(props.initial ?? '');
let timer: ReturnType<typeof setTimeout> | undefined;

// Internal staff notes autosave a second after typing stops.
watch(text, (value) => {
  clearTimeout(timer);
  timer = setTimeout(() => {
    api.patch(`/orders/${props.orderId}/notes`, { text: value }).catch(() => {});
  }, 1000);
});
</script>

<template>
  <div class="notes">
    <label for="order-notes">Internal notes</label>
    <textarea id="order-notes" v-model="text" rows="4"></textarea>
  </div>
</template>

<style scoped>
.notes {
  display: grid;
  gap: var(--space-1);
  margin-top: var(--space-6);
}
</style>
