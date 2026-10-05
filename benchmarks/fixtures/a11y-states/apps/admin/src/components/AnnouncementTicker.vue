<script setup lang="ts">
const messages = [
  'Autumn edit goes live Monday 09:00',
  'Carrier pickup moves to 15:30 from next week',
  'Remember to tag refunds over €200 for finance review',
];
</script>

<template>
  <div class="ticker">
    <div class="ticker-track">
      <span v-for="(m, i) in [...messages, ...messages]" :key="`${i}-${m}`" class="ticker-item">{{ m }}</span>
    </div>
  </div>
</template>

<style scoped>
.ticker {
  overflow: hidden;
  border-bottom: 1px solid var(--border);
  background: var(--surface-raised);
}

.ticker-track {
  display: flex;
  width: max-content;
  gap: var(--space-6);
  padding: var(--space-2) 0;
  animation: ticker-scroll 18s linear infinite;
}

@keyframes ticker-scroll {
  from {
    transform: translateX(0);
  }
  to {
    transform: translateX(-50%);
  }
}
</style>
