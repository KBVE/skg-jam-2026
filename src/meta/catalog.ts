// Power-up metadata shared by the in-run upgrade cards (and the meta shop, M4).
export interface PowerUp {
  id: string;
  name: string;
  desc: string;
  icon: string;
}

export const POWERUPS: Record<string, PowerUp> = {
  P_RICOCHET: { id: 'P_RICOCHET', name: 'Ricochet', desc: '+1 nearest bubble popped per pop', icon: '🎯' },
  P_AREA: { id: 'P_AREA', name: 'Area Blast', desc: '+1 cell pop radius', icon: '💥' },
  P_AUTOCLICK: { id: 'P_AUTOCLICK', name: 'Auto-Popper', desc: '+1 auto-pop per second', icon: '🤖' },
};
