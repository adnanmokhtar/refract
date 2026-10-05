<script setup lang="ts">
import { reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useQueryClient } from '@tanstack/vue-query';
import { api } from '../lib/api';

const props = defineProps<{ orderId: string; max: number }>();
const emit = defineEmits<{ done: [] }>();
const { t } = useI18n();
const qc = useQueryClient();

const amount = ref<number | null>(null);
const reason = ref('');
const errors = reactive<{ amount?: string; reason?: string }>({});

function validate() {
  errors.amount = !amount.value || amount.value <= 0 || amount.value > props.max / 100 ? 'Enter an amount up to the order total.' : undefined;
  errors.reason = reason.value.trim() ? undefined : 'Give a reason.';
  return !errors.amount && !errors.reason;
}

async function submitRefund() {
  if (!validate()) return;
  await api.post(`/orders/${props.orderId}/refunds`, { amount: Math.round((amount.value ?? 0) * 100), reason: reason.value });
  await qc.invalidateQueries({ queryKey: ['orders'] });
  emit('done');
}
</script>

<template>
  <form class="refund-form" @submit.prevent="submitRefund">
    <label for="refund-amount">{{ t('orders.amount') }}</label>
    <input id="refund-amount" v-model.number="amount" type="number" min="0" step="0.01" />
    <p v-if="errors.amount" class="field-error">{{ errors.amount }}</p>

    <label for="refund-reason">{{ t('orders.reason') }}</label>
    <textarea id="refund-reason" v-model="reason" rows="3"></textarea>
    <p v-if="errors.reason" class="field-error">{{ errors.reason }}</p>

    <button class="btn" type="submit">{{ t('orders.refund') }}</button>
  </form>
</template>

<style scoped>
.refund-form {
  display: grid;
  gap: var(--space-2);
  margin-top: var(--space-4);
}

.field-error {
  margin: 0;
  color: var(--danger);
  font-size: var(--font-sm);
}
</style>
