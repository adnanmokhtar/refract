<script setup lang="ts">
import { onMounted } from 'vue';
import { storeToRefs } from 'pinia';
import { useNotifications } from '../stores/notifications';

const store = useNotifications();
const { items, fetched } = storeToRefs(store);

onMounted(() => {
  if (!fetched.value) void store.load();
});
</script>

<template>
  <section class="notifications">
    <h2 class="notifications-title">Notifications</h2>
    <p v-if="fetched && items.length === 0" class="notifications-none">You're all caught up.</p>
    <ul v-else class="notifications-list">
      <li v-for="n in items" :key="n.id" :class="{ unread: !n.read }">{{ n.text }}</li>
    </ul>
  </section>
</template>

<style scoped>
.notifications {
  margin-top: var(--space-6);
}

.notifications-list {
  list-style: none;
  padding: 0;
}
</style>
