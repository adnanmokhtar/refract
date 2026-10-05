<script setup lang="ts">
defineProps<{ status: string }>();
</script>

<template>
  <span class="pill" :class="`pill--${status}`">{{ status }}</span>
</template>

<style scoped>
.pill {
  display: inline-block;
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-pill);
  background: var(--surface-raised);
  font-size: var(--font-sm);
}

.pill--refunded {
  background: var(--warning-bg);
  color: var(--warning-text);
}

.pill--late {
  background: #fde68a;
  color: #92400e;
}
</style>
