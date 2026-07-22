import { useSyncExternalStore } from 'react';
import { BASE_TIME } from '../game/constants';
import { META_UNLOCKS, type MetaBonuses } from './catalog';

const KEY = 'bubbleroguelite.meta.v1';

export interface Meta {
  currency: number;
  bonuses: MetaBonuses;
}

const DEFAULT: Meta = {
  currency: 0,
  bonuses: { baseTime: 0, ricochet: 0, area: 0, robots: 0 },
};

function load(): Meta {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const p = JSON.parse(raw);
      return { ...DEFAULT, ...p, bonuses: { ...DEFAULT.bonuses, ...p.bonuses } };
    }
  } catch {
    /* corrupt / unavailable -> defaults */
  }
  return structuredClone(DEFAULT);
}

let state: Meta = load();
const listeners = new Set<() => void>();

function persist(): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch {
    /* ignore quota/availability */
  }
  listeners.forEach((l) => l());
}

export function subscribe(l: () => void): () => void {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function getMeta(): Meta {
  return state;
}

/** React hook: reactive snapshot of the meta store. */
export function useMeta(): Meta {
  return useSyncExternalStore(subscribe, getMeta, getMeta);
}

export function bank(amount: number): void {
  if (amount <= 0) return;
  state = { ...state, currency: state.currency + amount };
  persist();
}

export function buy(id: string): boolean {
  const u = META_UNLOCKS.find((x) => x.id === id);
  if (!u || state.currency < u.cost) return false;
  state = { ...state, currency: state.currency - u.cost, bonuses: u.apply(state.bonuses) };
  persist();
  return true;
}

/** Loadout sent to Godot at run start. */
export function buildLoadout() {
  const b = state.bonuses;
  return {
    baseTime: BASE_TIME + b.baseTime,
    ricochet: b.ricochet,
    area: b.area,
    robots: b.robots,
  };
}

export function resetMeta(): void {
  state = structuredClone(DEFAULT);
  persist();
}
