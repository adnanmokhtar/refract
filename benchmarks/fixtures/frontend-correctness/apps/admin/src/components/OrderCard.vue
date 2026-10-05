<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import type { DispatchOrder } from '../lib/api';
import { api } from '../lib/api';

const props = defineProps<{ order: DispatchOrder }>();
const { t } = useI18n();

async function markPicked() {
  await api.patch(`/orders/${props.order.id}`, { status: 'ready' });
  props.order.status = 'ready';
}
</script>

<template>
  <article>
    <h2>{{ props.order.number }}</h2>
    <p>{{ props.order.customer }}</p>
    <span class="status">{{ t(`status.${props.order.status}`) }}</span>
    <button type="button" class="btn" @click.stop="markPicked">{{ t('dispatch.markReady') }}</button>
  </article>
</template>
