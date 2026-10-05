<script setup lang="ts">
import { onMounted, ref } from 'vue';

const columns = ref(3);

function measure() {
  columns.value = window.innerWidth > 1600 ? 4 : window.innerWidth > 1100 ? 3 : 2;
}

onMounted(() => {
  measure();
  window.addEventListener('resize', measure);
});
</script>

<template>
  <div class="board-columns" :style="{ '--cols': columns }"></div>
</template>
