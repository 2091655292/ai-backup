<script setup>
import { ref, computed, onMounted } from 'vue';
import { api, puzzles, clearToken } from '../api.js';
import PuzzleGrid from './PuzzleGrid.vue';
import GiftSuggestions from './GiftSuggestions.vue';

const emit = defineEmits(['logout']);
const props = defineProps({ user: { type: Object, required: true } });

const cards = ref([]);
const selectedId = ref(null);
const loading = ref(true);
const showAdd = ref(false);
const addName = ref('');
const addNote = ref('');
const saving = ref(false);
const toast = ref('');

const puzzleColors = {
  1: '#0a9d8f',
  2: '#3b82f6',
  3: '#8b5cf6',
};

const selectedCard = computed(() => cards.value.find((c) => c.id === selectedId.value) || null);

function showToast(msg) {
  toast.value = msg;
  setTimeout(() => (toast.value = ''), 1800);
}

const cacheKey = `puzzle_cards_cache_${props.user.id}`;

function readCache() {
  try {
    const v = JSON.parse(localStorage.getItem(cacheKey));
    return v && Array.isArray(v.cards) ? v : null;
  } catch {
    return null;
  }
}

function writeCache(rev, list) {
  localStorage.setItem(cacheKey, JSON.stringify({ rev, cards: list }));
}

function ensureSelection() {
  if (!cards.value.some((c) => c.id === selectedId.value)) {
    selectedId.value = cards.value[0]?.id ?? null;
  }
}

function snapshotList() {
  return cards.value.map((c) => ({
    id: c.id,
    name: c.name,
    note: c.note,
    createdAt: c.created_at,
    pieces: c.counts,
  }));
}

// 串行化同步：并发操作按序执行全量快照同步，避免旧 rev 请求互相 409
let syncQueue = Promise.resolve();

function syncAll() {
  const run = syncQueue.then(doSyncAll);
  syncQueue = run.catch(() => {});
  return run;
}

async function doSyncAll() {
  const rev = Date.now();
  try {
    await api.syncData({ rev, list: snapshotList() });
    writeCache(rev, cards.value);
  } catch (e) {
    if (e.status === 409 && e.data && Array.isArray(e.data.cards)) {
      // 本地版本过期（其他设备或旧接口写入更新）：直接采纳服务端返回的最新数据
      cards.value = e.data.cards;
      ensureSelection();
      writeCache(e.data.rev || 0, cards.value);
    } else {
      showToast(e.message);
    }
  }
}

async function load() {
  const cached = readCache();
  if (cached) {
    cards.value = cached.cards;
    ensureSelection();
    loading.value = false;
  }
  try {
    const data = await api.listCards();
    if (!cached || (data.rev || 0) >= (cached.rev || 0)) {
      cards.value = data.cards;
      writeCache(data.rev || 0, data.cards);
    } else {
      // 云端落后于本地缓存（KV 传播延迟或旧快照覆盖）：回推本地新状态自我修复
      await syncAll();
    }
    ensureSelection();
  } catch (e) {
    if (!cached) showToast(e.message);
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function selectCard(id) {
  selectedId.value = id;
}

async function addCard() {
  const name = addName.value.trim();
  if (!name) return;
  saving.value = true;
  try {
    const card = {
      id: `c${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`,
      name,
      note: addNote.value.trim(),
      created_at: new Date().toISOString(),
      counts: {},
      puzzleSummary: {},
    };
    recompute(card);
    cards.value.unshift(card);
    selectedId.value = card.id;
    addName.value = '';
    addNote.value = '';
    showAdd.value = false;
    showToast('卡片已添加');
    await syncAll();
  } catch (e) {
    showToast(e.message);
  } finally {
    saving.value = false;
  }
}

async function removeCard(card) {
  if (!confirm(`确定删除卡片「${card.name}」吗？其拼图记录将一并删除。`)) return;
  cards.value = cards.value.filter((c) => c.id !== card.id);
  if (selectedId.value === card.id) {
    selectedId.value = cards.value[0]?.id ?? null;
  }
  showToast('已删除');
  await syncAll();
}

function cardSummary(card) {
  const done = Object.values(card.puzzleSummary).filter((p) => p.complete).length;
  const dup = Object.values(card.puzzleSummary).reduce((s, p) => s + p.duplicate, 0);
  return `完成 ${done}/3 套 · 可赠送 ${dup} 片`;
}

async function recompute(card) {
  for (const p of [1, 2, 3]) {
    let owned = 0;
    let duplicate = 0;
    for (let s = 0; s < puzzles[p].total; s++) {
      const c = card.counts[`${p}:${s}`] || 0;
      if (c > 0) owned++;
      duplicate += Math.max(0, c - 1);
    }
    card.puzzleSummary[p] = {
      total: puzzles[p].total,
      owned,
      complete: owned >= puzzles[p].total,
      duplicate,
    };
  }
}

async function onPieceChange(puzzleNo, slot, count) {
  if (!selectedCard.value) return;
  selectedCard.value.counts[`${puzzleNo}:${slot}`] = count;
  recompute(selectedCard.value);
  await syncAll();
}

async function applyGift(item) {
  const from = cards.value.find((c) => c.id === item.fromId);
  const to = cards.value.find((c) => c.id === item.toId);
  if (!from || !to) return;
  const fromCount = from.counts[item.key] || 0;
  const toCount = to.counts[item.key] || 0;
  if (fromCount < 2 || toCount > 0) {
    showToast('数据已变化，请重试');
    return;
  }
  from.counts[item.key] = fromCount - 1;
  to.counts[item.key] = toCount + 1;
  recompute(from);
  recompute(to);
  await syncAll();
  showToast(`已将「${puzzles[item.puzzleNo].name} 第 ${item.slot + 1} 片」赠送给 ${to.name}`);
}

function logout() {
  clearToken();
  emit('logout');
}
</script>

<template>
  <div class="dash">
    <header class="topbar">
      <div class="brand">
        <span class="logo">🧩</span>
        <div>
          <h1>话费折拼图记录</h1>
          <p>中国移动 8 折充值活动 · 拼图收集与赠送管理</p>
        </div>
      </div>
      <div class="userbox">
        <span class="uname">{{ user.nickname || user.username }}</span>
        <button class="ghost" @click="logout">退出</button>
      </div>
    </header>

    <main class="layout">
      <aside class="sidebar">
        <div class="side-head">
          <h2>我的卡片</h2>
          <button class="add-btn" @click="showAdd = true">＋ 添加</button>
        </div>

        <div v-if="loading" class="empty">加载中…</div>
        <div v-else-if="cards.length === 0" class="empty">
          还没有卡片，点击右上角「添加」录入你的手机号。
        </div>

        <ul class="card-list">
          <li
            v-for="card in cards"
            :key="card.id"
            :class="{ active: card.id === selectedId }"
            @click="selectCard(card.id)"
          >
            <div class="card-name">
              <span class="phone-icon">📱</span>
              <div class="card-info">
                <span class="name">{{ card.name }}</span>
                <span class="note">{{ card.note || '无备注' }}</span>
                <span class="summary">{{ cardSummary(card) }}</span>
              </div>
            </div>
            <div class="card-dots">
              <span
                v-for="pn in [1, 2, 3]"
                :key="pn"
                class="dot"
                :class="{ done: card.puzzleSummary[pn]?.complete }"
                :style="card.puzzleSummary[pn]?.complete ? { background: puzzleColors[pn] } : {}"
                :title="`拼图${pn}：${card.puzzleSummary[pn].owned}/${card.puzzleSummary[pn].total}`"
              />
            </div>
            <button class="del-btn" title="删除卡片" @click.stop="removeCard(card)">✕</button>
          </li>
        </ul>
      </aside>

      <section class="content">
        <GiftSuggestions
          v-if="cards.length"
          :cards="cards"
          :colors="puzzleColors"
          @apply="applyGift"
        />

        <div v-if="!selectedCard" class="placeholder">
          <div class="placeholder-icon">🧩</div>
          <p>{{ loading ? '加载中…' : '请选择左侧的卡片开始记录，或先添加一张卡片。' }}</p>
        </div>

        <template v-else>
          <div class="card-head">
            <h2>{{ selectedCard.name }}</h2>
            <span v-if="selectedCard.note" class="card-note">{{ selectedCard.note }}</span>
          </div>

          <div class="puzzle-list">
            <PuzzleGrid
              v-for="pn in [1, 2, 3]"
              :key="pn"
              :puzzle-no="pn"
              :name="puzzles[pn].name"
              :total="puzzles[pn].total"
              :cols="puzzles[pn].cols"
              :desc="puzzles[pn].desc"
              :counts="Object.fromEntries(
                Object.entries(selectedCard.counts)
                  .filter(([k]) => k.startsWith(pn + ':'))
                  .map(([k, v]) => [Number(k.split(':')[1]), v])
              )"
              :color="puzzleColors[pn]"
              @change="(slot, count) => onPieceChange(pn, slot, count)"
            />
          </div>
        </template>
      </section>
    </main>

    <div v-if="showAdd" class="modal-mask" @click.self="showAdd = false">
      <div class="modal">
        <h3>添加卡片</h3>
        <label>号码 / 名称</label>
        <input v-model="addName" type="text" placeholder="例如 13800138000" @keyup.enter="addCard" />
        <label>备注（可选）</label>
        <input v-model="addNote" type="text" placeholder="例如 副卡、妈妈手机" @keyup.enter="addCard" />
        <div class="modal-actions">
          <button class="ghost" @click="showAdd = false">取消</button>
          <button class="primary" :disabled="!addName.trim() || saving" @click="addCard">
            {{ saving ? '保存中…' : '保存' }}
          </button>
        </div>
      </div>
    </div>

    <transition name="fade">
      <div v-if="toast" class="toast">{{ toast }}</div>
    </transition>
  </div>
</template>

<style scoped>
.dash {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.topbar {
  background: var(--card-bg);
  border-bottom: 1px solid var(--border);
  padding: 12px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
}

.brand .logo {
  font-size: 30px;
}

.brand h1 {
  font-size: 17px;
}

.brand p {
  color: var(--text-soft);
  font-size: 12px;
  margin-top: 2px;
}

.userbox {
  display: flex;
  align-items: center;
  gap: 10px;
}

.uname {
  color: var(--text-soft);
  font-size: 14px;
}

.ghost {
  color: var(--text-soft);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 6px 12px;
  font-size: 13px;
  transition: all 0.15s;
}

.ghost:hover {
  color: var(--danger);
  border-color: var(--danger);
}

.layout {
  flex: 1;
  display: flex;
  gap: 16px;
  padding: 16px 20px;
  align-items: flex-start;
}

.sidebar {
  width: 280px;
  flex-shrink: 0;
  background: var(--card-bg);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 14px;
  position: sticky;
  top: 16px;
  max-height: calc(100vh - 100px);
  overflow-y: auto;
}

.side-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.side-head h2 {
  font-size: 15px;
}

.add-btn {
  background: var(--brand);
  color: #fff;
  border-radius: 8px;
  padding: 6px 12px;
  font-size: 13px;
  font-weight: 600;
}

.add-btn:hover {
  background: var(--brand-dark);
}

.empty {
  color: var(--text-soft);
  font-size: 13px;
  text-align: center;
  padding: 30px 10px;
  line-height: 1.6;
}

.card-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.card-list li {
  position: relative;
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 10px 10px 10px 12px;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
}

.card-list li:hover {
  border-color: #b6c8d6;
}

.card-list li.active {
  border-color: var(--brand);
  background: var(--brand-light);
}

.card-name {
  display: flex;
  gap: 10px;
  align-items: flex-start;
}

.phone-icon {
  font-size: 18px;
  line-height: 1.4;
}

.card-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.card-info .name {
  font-weight: 600;
  font-size: 14px;
  word-break: break-all;
}

.card-info .note {
  color: var(--text-soft);
  font-size: 12px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card-info .summary {
  color: var(--text-soft);
  font-size: 11px;
  margin-top: 2px;
}

.card-dots {
  display: flex;
  gap: 6px;
  margin-top: 8px;
}

.dot {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: var(--bg);
  border: 1px solid var(--border);
}

.del-btn {
  position: absolute;
  top: 6px;
  right: 6px;
  color: var(--text-soft);
  font-size: 12px;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  opacity: 0;
  transition: opacity 0.15s;
}

.card-list li:hover .del-btn {
  opacity: 1;
}

.del-btn:hover {
  color: var(--danger);
  background: #fde8e8;
}

.content {
  flex: 1;
  min-width: 0;
}

.placeholder {
  background: var(--card-bg);
  border: 1px dashed var(--border);
  border-radius: 14px;
  padding: 60px 20px;
  text-align: center;
  color: var(--text-soft);
}

.placeholder-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.card-head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 14px;
}

.card-head h2 {
  font-size: 20px;
}

.card-note {
  color: var(--text-soft);
  font-size: 13px;
}

.puzzle-list {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.modal-mask {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  padding: 20px;
}

.modal {
  background: var(--card-bg);
  border-radius: 14px;
  padding: 22px;
  width: 100%;
  max-width: 360px;
}

.modal h3 {
  font-size: 17px;
  margin-bottom: 14px;
}

.modal label {
  display: block;
  font-size: 13px;
  color: var(--text-soft);
  margin: 12px 0 5px;
}

.modal input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 8px;
  font-size: 14px;
  outline: none;
}

.modal input:focus {
  border-color: var(--brand);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 18px;
}

.primary {
  background: var(--brand);
  color: #fff;
  border-radius: 8px;
  padding: 8px 18px;
  font-size: 14px;
  font-weight: 600;
}

.primary:hover {
  background: var(--brand-dark);
}

.primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.toast {
  position: fixed;
  bottom: 30px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(15, 23, 42, 0.9);
  color: #fff;
  padding: 10px 20px;
  border-radius: 999px;
  font-size: 14px;
  z-index: 100;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.25s;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

@media (max-width: 768px) {
  .layout {
    flex-direction: column;
    padding: 12px;
  }

  .sidebar {
    width: 100%;
    position: static;
    max-height: none;
  }

  .card-list {
    flex-direction: row;
    overflow-x: auto;
  }

  .card-list li {
    min-width: 220px;
  }
}
</style>
