<script setup lang="ts">
import { onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { t } from '@acme/i18n';
import { useOrdersStore } from '../stores/orders-store';
import OrderTable from './order-table.vue';

const orders = useOrdersStore();
const { items, isLoading } = storeToRefs(orders);
onMounted(() => orders.load());
</script>

<template>
  <section class="mt-6">
    <h2 class="text-lg">{{ t('orders.title') }}</h2>
    <p v-if="isLoading">{{ t('common.loading') }}</p>
    <OrderTable v-else :orders="items" />
  </section>
</template>
