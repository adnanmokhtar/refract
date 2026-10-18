<script setup lang="ts">
import OrderList from './components/OrderList.vue';
import OrderFilters from './components/order-filters.vue';
</script>

<template>
  <main class="min-h-screen bg-surface p-6 text-ink">
    <OrderFilters />
    <OrderList />
  </main>
</template>
