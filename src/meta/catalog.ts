// Power-up metadata shared by the in-run upgrade cards (and the meta shop, M4).
export interface PowerUp {
  id: string;
  name: string;
  desc: string;
  icon: string;
}

export const POWERUPS: Record<string, PowerUp> = {
  P_RICOCHET: { id: 'P_RICOCHET', name: 'Ricochet', desc: '+1 nearest bubble popped per pop (procs every 3 pops)', icon: 'target' },
  P_AREA: { id: 'P_AREA', name: 'Area Blast', desc: '+1 cell pop radius (procs every 5 pops)', icon: 'bomb' },
  P_ROBOT: { id: 'P_ROBOT', name: 'Deploy Robot', desc: '+1 robot that walks over and pops bubbles', icon: 'robot' },
};

export interface MetaBonuses {
  baseTime: number; // extra seconds
  ricochet: number;
  area: number;
  robots: number;
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
  { id: 'U_START_ROBOT', name: 'Start Robot', desc: '+1 starting robot', icon: 'robot', cost: 5,
    apply: (b) => ({ ...b, robots: b.robots + 1 }) },
];
