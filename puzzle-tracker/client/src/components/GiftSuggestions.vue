<script setup>
import { computed } from 'vue';
import { puzzles } from '../api.js';

const props = defineProps({
  cards: { type: Array, required: true },
  colors: { type: Object, required: true },
});

const emit = defineEmits(['apply']);

const puzzleNos = [1, 2, 3];

function prevComplete(card, pn) {
  return card.puzzleSummary?.[pn - 1]?.complete === true;
}

function ownsAny(card, pn) {
  const prefix = `${pn}:`;
  return Object.entries(card.counts || {}).some(([k, v]) => k.startsWith(prefix) && v > 0);
}

function isUnlocked(card, pn) {
  if (pn === 1) return true;
  return prevComplete(card, pn) || ownsAny(card, pn);
}

const suggestions = computed(() => {
  const list = [];
  for (const pn of puzzleNos) {
    for (let slot = 0; slot < puzzles[pn].total; slot++) {
      const key = `${pn}:${slot}`;
      const givers = props.cards
        .map((card) => ({ card, extra: Math.max(0, (card.counts?.[key] || 0) - 1) }))
        .filter((g) => g.extra > 0);
      if (givers.length === 0) continue;
      const receivers = props.cards.filter(
        (card) => (card.counts?.[key] || 0) === 0 && isUnlocked(card, pn),
      );
      let gi = 0;
      for (const receiver of receivers) {
        while (gi < givers.length && givers[gi].extra <= 0) gi++;
        if (gi >= givers.length) break;
        const giver = givers[gi];
        list.push({
          puzzleNo: pn,
          slot,
          key,
          fromId: giver.card.id,
          fromName: giver.card.name,
          fromCount: giver.card.counts?.[key] || 0,
          toId: receiver.id,
          toName: receiver.name,
        });
        giver.extra -= 1;
      }
    }
  }
  return list;
});

const groups = computed(() => {
  const map = new Map();
  for (const item of suggestions.value) {
    if (!map.has(item.toId)) {
      map.set(item.toId, { toId: item.toId, toName: item.toName, items: [] });
    }
    map.get(item.toId).items.push(item);
  }
  return [...map.values()];
});

function pieceLabel(item) {
  return `${puzzles[item.puzzleNo].name} · 第 ${item.slot + 1} 片`;
}
</script>

<template>
  <section v-if="groups.length" class="gift-panel">
    <header class="gift-head">
      <h3>赠送建议</h3>
      <p>根据各号码的拼图数量自动计算，把多余的片送给缺少该片的号码。</p>
    </header>

    <div class="gift-groups">
      <div v-for="group in groups" :key="group.toId" class="gift-group">
        <div class="gift-to">
          <span class="to-icon">📱</span>
          <span class="to-name">{{ group.toName }}</span>
          <span class="to-label">还缺以下片</span>
        </div>
        <ul class="gift-items">
          <li v-for="item in group.items" :key="item.key + item.fromId">
            <span
              class="piece-chip"
              :style="{ background: colors[item.puzzleNo] }"
            >{{ pieceLabel(item) }}</span>
            <span class="arrow">←</span>
            <span class="from-name">{{ item.fromName }}</span>
            <span class="from-extra">多余 {{ item.fromCount - 1 }} 片</span>
            <button class="gift-btn" @click="emit('apply', item)">赠送</button>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>

<style scoped>
.gift-panel {
  background: linear-gradient(135deg, #fffbeb, #fef3c7);
  border: 1px solid #fcd34d;
  border-radius: 14px;
  padding: 16px 18px;
  margin-bottom: 18px;
}

.gift-head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 12px;
}

.gift-head h3 {
  font-size: 16px;
  color: #92400e;
}

.gift-head p {
  color: #b45309;
  font-size: 12px;
}

.gift-groups {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.gift-group {
  background: rgba(255, 255, 255, 0.7);
  border: 1px solid #fde68a;
  border-radius: 10px;
  padding: 10px 12px;
}

.gift-to {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.to-icon {
  font-size: 15px;
}

.to-name {
  font-weight: 700;
  font-size: 14px;
}

.to-label {
  color: var(--text-soft);
  font-size: 12px;
}

.gift-items {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.gift-items li {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  font-size: 13px;
}

.piece-chip {
  color: #fff;
  border-radius: 6px;
  padding: 2px 8px;
  font-size: 12px;
  font-weight: 600;
}

.arrow {
  color: var(--text-soft);
}

.from-name {
  font-weight: 600;
  word-break: break-all;
}

.from-extra {
  color: #92400e;
  font-size: 12px;
  background: #fef3c7;
  border-radius: 999px;
  padding: 1px 8px;
}

.gift-btn {
  margin-left: auto;
  background: #f59e0b;
  color: #fff;
  border-radius: 8px;
  padding: 4px 12px;
  font-size: 13px;
  font-weight: 600;
  transition: background 0.15s;
}

.gift-btn:hover {
  background: #d97706;
}
</style>
