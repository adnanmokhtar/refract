<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { AdminOrder } from '../lib/api';
import RefundForm from './RefundForm.vue';
import NotesEditor from './NotesEditor.vue';

const props = defineProps<{ order: AdminOrder }>();
const emit = defineEmits<{ close: [] }>();
const { t } = useI18n();
</script>

<template>
  <Transition name="drawer" appear>
    <aside role="dialog" aria-modal="true" aria-labelledby="refund-title" class="drawer">
      <header class="drawer-header">
        <h2 id="refund-title">{{ t('orders.refundTitle', { number: props.order.number }) }}</h2>
        <button class="btn" type="button" @click="emit('close')">{{ t('common.close') }}</button>
      </header>
      <RefundForm :order-id="props.order.id" :max="props.order.total" @done="emit('close')" />
      <NotesEditor :order-id="props.order.id" />
    </aside>
  </Transition>
</template>

<style scoped>
.drawer {
  position: fixed;
  inset-block: 0;
  right: 0;
  width: 420px;
  padding: var(--space-6);
  background: var(--surface);
  box-shadow: var(--shadow-overlay);
  z-index: var(--z-overlay);
}

.drawer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
