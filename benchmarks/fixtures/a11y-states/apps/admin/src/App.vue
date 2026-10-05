<script setup lang="ts">
import { onErrorCaptured, ref } from 'vue';
import { RouterView, useRouter } from 'vue-router';
import AppSidebar from './components/AppSidebar.vue';
import AnnouncementTicker from './components/AnnouncementTicker.vue';
import CookieNotice from './components/CookieNotice.vue';

const crashed = ref(false);
const router = useRouter();
onErrorCaptured(() => {
  crashed.value = true;
  return false;
});
router.afterEach(() => (crashed.value = false));
</script>

<template>
  <div class="app-shell">
    <AppSidebar />
    <div class="app-main">
      <AnnouncementTicker />
      <main id="main" class="app-content">
        <div v-if="crashed" role="alert" class="card">
          <p>This page crashed.</p>
          <button class="btn" type="button" @click="router.go(0)">Reload</button>
        </div>
        <RouterView v-else />
      </main>
    </div>
    <CookieNotice />
  </div>
</template>
