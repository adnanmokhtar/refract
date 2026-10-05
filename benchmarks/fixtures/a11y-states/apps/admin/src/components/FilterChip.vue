<script setup lang="ts">
defineProps<{ label: string }>();
defineEmits<{ remove: [] }>();
</script>

<template>
  <span class="chip">
    {{ label }}
    <button class="chip-remove" type="button" @click="$emit('remove')">×</button>
  </span>
</template>

<style scoped>
.chip {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  padding: var(--space-1) var(--space-2);
  border: 1px solid var(--border);
  border-radius: var(--radius-pill);
}

.chip-remove {
  border: 0;
  background: transparent;
  cursor: pointer;
}
</style>
