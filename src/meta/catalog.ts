// Power-up metadata shared by the in-run upgrade cards (and the meta shop, M4).
export interface PowerUp {
  id: string;
  name: string;
  desc: string;
  icon: string;
}

export const POWERUPS: Record<string, PowerUp> = {
  P_RICOCHET: { id: 'P_RICOCHET', name: 'Ricochet', desc: '+1 nearest bubble popped per pop', icon: 'target' },
  P_AREA: { id: 'P_AREA', name: 'Area Blast', desc: '+1 cell pop radius', icon: 'bomb' },
  P_AUTOCLICK: { id: 'P_AUTOCLICK', name: 'Auto-Popper', desc: '+1 auto-pop per second', icon: 'robot' },
};

export interface MetaBonuses {
  baseTime: number; // extra seconds
  ricochet: number;
  area: number;
  autoclick: number;
}

export interface MetaUnlock {
  id: string;
  name: string;
  desc: string;
  icon: string;
  cost: number;
  apply: (b: MetaBonuses) => MetaBonuses;
}

// Permanent, stackable unlocks bought with currency between runs.
export const META_UNLOCKS: MetaUnlock[] = [
  { id: 'U_BASE_TIME', name: '+5s Base Time', desc: 'Start each run with more time', icon: 'hourglass', cost: 3,
    apply: (b) => ({ ...b, baseTime: b.baseTime + 5 }) },
  { id: 'U_START_RICOCHET', name: 'Start Ricochet', desc: '+1 starting ricochet', icon: 'target', cost: 5,
    apply: (b) => ({ ...b, ricochet: b.ricochet + 1 }) },
  { id: 'U_START_AREA', name: 'Start Area', desc: '+1 starting pop radius', icon: 'bomb', cost: 8,
    apply: (b) => ({ ...b, area: b.area + 1 }) },
  { id: 'U_START_AUTOCLICK', name: 'Start Auto-Pop', desc: '+1 starting auto-popper', icon: 'robot', cost: 5,
    apply: (b) => ({ ...b, autoclick: b.autoclick + 1 }) },
];
