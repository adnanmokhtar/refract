<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { gsap } from 'gsap';
import { useI18n } from 'vue-i18n';

const props = defineProps<{ value: number }>();
const { n } = useI18n();
const shown = ref(0);
const tween = { v: 0 };

function animateTo(target: number) {
  gsap.to(tween, {
    v: target,
    duration: 1.2,
    ease: 'power2.out',
    onUpdate: () => {
      shown.value = Math.round(tween.v);
    },
  });
}

onMounted(() => animateTo(props.value));
watch(() => props.value, animateTo);
</script>

<template>
  <p class="kpi">{{ n(shown / 100, 'currency') }}</p>
</template>

<style scoped>
.kpi {
  font-size: var(--font-display);
  font-variant-numeric: tabular-nums;
}
</style>
