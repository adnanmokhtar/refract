<script setup lang="ts">
import { ref } from 'vue';
import draggable from 'vuedraggable';
import { useI18n } from 'vue-i18n';
import { api } from '../lib/api';

type MenuItem = { id: string; label: string; href: string };

const { t } = useI18n();
const items = ref<MenuItem[]>([
  { id: 'living', label: 'Living room', href: '/rooms/living' },
  { id: 'bedroom', label: 'Bedroom', href: '/rooms/bedroom' },
  { id: 'dining', label: 'Dining', href: '/rooms/dining' },
]);

async function persist() {
  await api.put('/storefront/menu', { ids: items.value.map((i) => i.id) });
}
</script>

<template>
  <section>
    <h1>{{ t('nav.menu') }}</h1>
    <draggable v-model="items" item-key="id" tag="ol" class="menu-list" handle=".grip" @end="persist">
      <template #item="{ element }">
        <li class="card menu-item">
          <span class="grip" aria-hidden="true">⋮⋮</span>
          <span>{{ element.label }}</span>
          <code>{{ element.href }}</code>
        </li>
      </template>
    </draggable>
  </section>
</template>

<style scoped>
.menu-list {
  list-style: none;
  padding: 0;
  display: grid;
  gap: var(--space-2);
}

.menu-item {
  display: grid;
  grid-template-columns: 2rem 1fr auto;
  align-items: center;
}

.grip {
  cursor: grab;
}
</style>
