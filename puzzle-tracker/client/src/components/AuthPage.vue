<script setup>
import { ref } from 'vue';
import { api } from '../api.js';

const emit = defineEmits(['authed']);

const mode = ref('login');
const username = ref('');
const password = ref('');
const nickname = ref('');
const error = ref('');
const loading = ref(false);

function switchMode(m) {
  mode.value = m;
  error.value = '';
}

async function submit() {
  error.value = '';
  if (!username.value.trim() || password.value.length < 4) {
    error.value = '请填写用户名和至少 4 位密码';
    return;
  }
  loading.value = true;
  try {
    const body = { username: username.value.trim(), password: password.value };
    if (mode.value === 'register') body.nickname = nickname.value.trim();
    const data = mode.value === 'login' ? await api.login(body) : await api.register(body);
    emit('authed', data);
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card">
      <div class="auth-logo">🧩</div>
      <h1>话费折拼图记录工具</h1>
      <p class="subtitle">多卡拼图收集与赠送记录</p>

      <div class="tabs">
        <button :class="{ active: mode === 'login' }" @click="switchMode('login')">登录</button>
        <button :class="{ active: mode === 'register' }" @click="switchMode('register')">注册</button>
      </div>

      <form @submit.prevent="submit">
        <label>用户名</label>
        <input v-model="username" type="text" autocomplete="username" placeholder="2-30 位字母、数字或中文" />

        <label v-if="mode === 'register'">昵称（可选）</label>
        <input v-if="mode === 'register'" v-model="nickname" type="text" placeholder="你的称呼" />

        <label>密码</label>
        <input v-model="password" type="password" autocomplete="current-password" placeholder="至少 4 位" />

        <p v-if="error" class="error">{{ error }}</p>

        <button class="submit" type="submit" :disabled="loading">
          {{ loading ? '请稍候…' : mode === 'login' ? '登录' : '注册并登录' }}
        </button>
      </form>

      <p class="tip">注册后数据保存在云端账号下，可在多台设备上同步使用</p>
    </div>
  </div>
</template>

<style scoped>
.auth-wrap {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: linear-gradient(160deg, #0a9d8f 0%, #0d6e8a 60%, #123a5e 100%);
}

.auth-card {
  background: var(--card-bg);
  border-radius: 16px;
  padding: 32px 28px;
  width: 100%;
  max-width: 400px;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.25);
}

.auth-logo {
  font-size: 44px;
  text-align: center;
}

h1 {
  text-align: center;
  font-size: 20px;
  margin-top: 8px;
}

.subtitle {
  text-align: center;
  color: var(--text-soft);
  font-size: 13px;
  margin: 6px 0 20px;
}

.tabs {
  display: flex;
  background: var(--bg);
  border-radius: 10px;
  padding: 4px;
  margin-bottom: 18px;
}

.tabs button {
  flex: 1;
  padding: 9px;
  border-radius: 8px;
  font-size: 14px;
  color: var(--text-soft);
}

.tabs button.active {
  background: var(--card-bg);
  color: var(--brand);
  font-weight: 600;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

label {
  display: block;
  font-size: 13px;
  color: var(--text-soft);
  margin: 12px 0 5px;
}

input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 8px;
  font-size: 14px;
  outline: none;
  transition: border-color 0.15s;
}

input:focus {
  border-color: var(--brand);
}

.error {
  color: var(--danger);
  font-size: 13px;
  margin-top: 12px;
}

.submit {
  width: 100%;
  margin-top: 18px;
  padding: 11px;
  background: var(--brand);
  color: #fff;
  border-radius: 8px;
  font-size: 15px;
  font-weight: 600;
  transition: background 0.15s;
}

.submit:hover {
  background: var(--brand-dark);
}

.submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.tip {
  text-align: center;
  color: var(--text-soft);
  font-size: 12px;
  margin-top: 14px;
}
</style>
