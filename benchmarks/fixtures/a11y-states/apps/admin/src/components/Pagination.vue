<script setup lang="ts">
const page = defineModel<number>({ required: true });
defineProps<{ pages: number }>();
</script>

<template>
  <nav class="pagination" aria-label="Pagination">
    <button
      v-for="n in pages"
      :key="n"
      class="page-btn"
      type="button"
      :aria-current="n === page ? 'page' : undefined"
      @click="page = n"
    >
      {{ n }}
    </button>
  </nav>
</template>

<style scoped>
.pagination {
  display: flex;
  gap: 0;
  margin-top: var(--space-4);
}

.page-btn {
  width: 20px;
  height: 20px;
  padding: 0;
  border: 1px solid var(--border);
  background: var(--surface);
  font-size: var(--font-sm);
  cursor: pointer;
}

.page-btn[aria-current='page'] {
  background: var(--brand);
  color: var(--surface);
}
</style>
