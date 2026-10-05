<script setup lang="ts">
const model = defineModel<string | null>({ required: true });
const options = ['paid', 'shipped', 'delivered', 'refunded'] as const;
</script>

<template>
  <ul role="listbox" aria-label="Status" class="status-filter">
    <li
      v-for="option in options"
      :key="option"
      role="option"
      :aria-selected="model === option"
      tabindex="0"
      class="status-option"
      @click="model = model === option ? null : option"
    >
      {{ option }}
    </li>
  </ul>
</template>

<style scoped>
.status-filter {
  display: flex;
  gap: var(--space-1);
  list-style: none;
  padding: 0;
  margin: 0;
}

.status-option {
  padding: var(--space-1) var(--space-3);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  cursor: pointer;
}

.status-option[aria-selected='true'] {
  background: var(--surface-raised);
  border-color: var(--brand);
}
</style>
