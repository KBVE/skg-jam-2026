import { useState } from 'react';
import { useBusEvent } from '../bus';
import { godotSend } from '../godot/bridge';
import { POWERUPS } from '../meta/catalog';
import { Icon } from './Icon';
import type { SheetClearPayload, StatePayload } from '../game/events';

/** Overlay shown during SHEET_CLEAR: 3 upgrade choices; picking resumes the run. */
export function UpgradeCards() {
  const [choices, setChoices] = useState<string[] | null>(null);
  const [sheet, setSheet] = useState(0);

  useBusEvent<SheetClearPayload>('game:sheet_clear', (p) => {
    setChoices(p.choices);
    setSheet(p.sheet);
  });
  useBusEvent<StatePayload>('game:state', (p) => {
    if (p.state !== 'SHEET_CLEAR') setChoices(null);
  });

  if (!choices) return null;

  const pick = (id: string) => {
    godotSend('pick_upgrade', { id });
    setChoices(null);
  };

  return (
    <div className="cards-overlay">
      <h2>Sheet {sheet + 1} cleared — pick a power-up</h2>
      <div className="cards">
        {choices.map((id, i) => {
          const p = POWERUPS[id];
          return (
            <button key={i} className="card" onClick={() => pick(id)}>
              <div className="card-icon"><Icon name={p?.icon ?? 'help'} /></div>
              <div className="card-name">{p?.name ?? id}</div>
              <div className="card-desc">{p?.desc ?? ''}</div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
