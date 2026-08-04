<script setup>
import { ref, onMounted } from 'vue';
import AuthPage from './components/AuthPage.vue';
import Dashboard from './components/Dashboard.vue';
import { api, getToken, setToken } from './api.js';

const user = ref(null);
const booting = ref(true);

function onAuthed(data) {
  setToken(data.token);
  user.value = data.user;
}

function onLogout() {
  user.value = null;
}

onMounted(async () => {
  const token = getToken();
  if (!token) {
    booting.value = false;
    return;
  }
  try {
    const data = await api.me();
    user.value = data.user;
  } catch {
    /* token invalid */
  } finally {
    booting.value = false;
  }
});
</script>

<template>
  <div v-if="booting" class="boot">加载中…</div>
  <Dashboard v-else-if="user" :user="user" @logout="onLogout" />
  <AuthPage v-else @authed="onAuthed" />
</template>

<style scoped>
.boot {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-soft);
}
</style>
