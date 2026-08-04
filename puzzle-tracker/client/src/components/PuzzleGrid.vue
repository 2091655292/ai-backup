<script setup>
import { computed } from 'vue';

const props = defineProps({
  puzzleNo: { type: Number, required: true },
  name: { type: String, required: true },
  total: { type: Number, required: true },
  cols: { type: Number, required: true },
  desc: { type: String, default: '' },
  counts: { type: Object, default: () => ({}) },
  color: { type: String, required: true },
});

const emit = defineEmits(['change']);

const slots = computed(() => Array.from({ length: props.total }, (_, i) => i));

function countOf(slot) {
  return props.counts[slot] || 0;
}

function setCount(slot, count) {
  const next = Math.min(99, Math.max(0, count));
  emit('change', slot, next);
}

const owned = computed(() => slots.value.filter((s) => countOf(s) > 0).length);
const complete = computed(() => owned.value >= props.total);
const duplicate = computed(() =>
  slots.value.reduce((sum, s) => sum + Math.max(0, countOf(s) - 1), 0),
);

function gridStyle() {
  return {
    gridTemplateColumns: `repeat(${props.cols}, minmax(0, 1fr))`,
  };
}
</script>

<template>
  <section class="puzzle" :class="{ complete }">
    <header class="puzzle-header">
      <div>
        <h3>{{ name }}</h3>
        <span class="desc">{{ desc }}</span>
      </div>
      <div class="stats">
        <span class="badge complete-badge" :class="{ done: complete }">
          {{ complete ? '已完成' : `${owned}/${total}` }}
        </span>
        <span v-if="duplicate > 0" class="badge dup-badge" title="多余可赠送的片数">可赠送 {{ duplicate }}</span>
      </div>
    </header>

    <div class="grid" :style="gridStyle()">
      <div
        v-for="slot in slots"
        :key="slot"
        class="piece"
        :class="[{ has: countOf(slot) > 0, more: countOf(slot) > 1 }, `p${puzzleNo}`]"
        :style="countOf(slot) > 0 ? { background: color } : {}"
        :title="countOf(slot) > 0 ? '拥有该片' : '尚未拥有该片'"
      >
        <div class="piece-top">
          <span class="piece-no">{{ slot + 1 }}</span>
          <span v-if="countOf(slot) > 1" class="extra" :title="`多余 ${countOf(slot) - 1} 片，可赠送`">+{{ countOf(slot) - 1 }}</span>
        </div>
        <div class="stepper">
          <button
            class="step"
            :class="{ off: countOf(slot) === 0 }"
            :disabled="countOf(slot) === 0"
            @click="setCount(slot, countOf(slot) - 1)"
            :title="countOf(slot) === 0 ? '已是 0 片' : '减少一片'"
          >−</button>
          <span class="num" :class="{ has: countOf(slot) > 0 }">{{ countOf(slot) }}</span>
          <button class="step" @click="setCount(slot, countOf(slot) + 1)" :title="'增加一片'">＋</button>
        </div>
      </div>
    </div>

    <div class="ops">
      <span class="hint">点击「＋／−」调整该片数量，0 表示未拥有，2 及以上表示有重复片可赠送</span>
      <div v-if="duplicate > 0" class="gift-box" :style="{ borderColor: color }">
        <span>本套可赠送的片：</span>
        <span
          v-for="slot in slots"
          :key="'g' + slot"
          v-show="countOf(slot) > 1"
          class="gift-chip"
          :style="{ background: color }"
        >
          {{ slot + 1 }} ×{{ countOf(slot) - 1 }}
        </span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.puzzle {
  background: var(--card-bg);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 18px;
  transition: box-shadow 0.2s;
}

.puzzle.complete {
  border-color: #a7f3d0;
}

.puzzle-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 14px;
}

.puzzle-header h3 {
  font-size: 16px;
}

.desc {
  color: var(--text-soft);
  font-size: 12px;
  margin-left: 8px;
}

.stats {
  display: flex;
  gap: 8px;
  align-items: center;
}

.badge {
  font-size: 12px;
  font-weight: 600;
  padding: 4px 10px;
  border-radius: 999px;
}

.complete-badge {
  background: var(--bg);
  color: var(--text-soft);
}

.complete-badge.done {
  background: #d1fae5;
  color: #047857;
}

.dup-badge {
  background: #fef3c7;
  color: #92400e;
}

.grid {
  display: grid;
  gap: 10px;
}

.piece {
  position: relative;
  aspect-ratio: 1;
  border: 2px dashed var(--border);
  border-radius: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  user-select: none;
  transition: transform 0.1s, border-color 0.1s;
  background: #f8fafc;
}

.piece:hover {
  transform: scale(1.02);
}

.piece.has {
  border-style: solid;
}

.piece.has.more {
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.12);
}

.piece-top {
  display: flex;
  align-items: center;
  gap: 6px;
  min-height: 20px;
}

.piece-no {
  font-size: 15px;
  font-weight: 700;
  color: var(--text-soft);
}

.piece.has .piece-no {
  color: #fff;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}

.stepper {
  display: flex;
  align-items: center;
  gap: 4px;
}

.step {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  font-size: 16px;
  line-height: 1;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.85);
  color: var(--text);
  border: 1px solid var(--border);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
  transition: background 0.12s, transform 0.1s;
}

.piece.has .step {
  background: rgba(255, 255, 255, 0.92);
}

.step:hover:not(:disabled) {
  background: #ffffff;
  transform: scale(1.08);
}

.step:active:not(:disabled) {
  transform: scale(0.94);
}

.step.off {
  opacity: 0.4;
  cursor: not-allowed;
}

.step:disabled {
  cursor: not-allowed;
}

.num {
  min-width: 26px;
  text-align: center;
  font-size: 15px;
  font-weight: 700;
  color: var(--text-soft);
  line-height: 26px;
}

.num.has {
  color: #fff;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}

.extra {
  position: absolute;
  top: -6px;
  right: -6px;
  background: var(--gold);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  border-radius: 999px;
  padding: 1px 7px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.25);
}

.ops {
  margin-top: 14px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.hint {
  color: var(--text-soft);
  font-size: 12px;
}

.gift-box {
  border: 1px dashed var(--border);
  border-radius: 10px;
  padding: 8px 10px;
  font-size: 12px;
  color: var(--text-soft);
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
}

.gift-chip {
  color: #fff;
  border-radius: 6px;
  padding: 2px 8px;
  font-size: 12px;
  font-weight: 600;
}
</style>
