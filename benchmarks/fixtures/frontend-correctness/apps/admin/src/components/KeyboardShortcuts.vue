<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();

function onKey(e: KeyboardEvent) {
  if (e.altKey && e.key === 'd') void router.push('/dispatch');
  if (e.altKey && e.key === 'o') void router.push('/orders');
}

onMounted(() => window.addEventListener('keydown', onKey));
onUnmounted(() => window.removeEventListener('keydown', onKey));
</script>

<template>
  <span hidden></span>
</template>
