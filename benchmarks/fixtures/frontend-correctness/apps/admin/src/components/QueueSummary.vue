<script setup lang="ts">
defineProps<{ count: number }>();
</script>

<template>
  <p class="queue-summary">{{ count }} order{{ count === 1 ? '' : 's' }} waiting for a picker</p>
</template>
