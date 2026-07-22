import { useState } from 'react';
import { useBusEvent } from '../bus';
import { godotSend } from '../godot/bridge';
import { BASE_TIME, TIME_PURCHASE_COST, TIME_PURCHASE_SECONDS } from '../game/constants';
import { POWERUPS } from '../meta/catalog';
import { Icon } from './Icon';
import type { SheetClearPayload, StatePayload, ScorePayload, TimePayload } from '../game/events';

/** Overlay shown during SHEET_CLEAR: 3 upgrade choices; picking resumes the run. */
export function UpgradeCards() {
  const [choices, setChoices] = useState<string[] | null>(null);
  const [sheet, setSheet] = useState(0);
  const [score, setScore] = useState(0);
  const [time, setTime] = useState(BASE_TIME);

  useBusEvent<SheetClearPayload>('game:sheet_clear', (p) => {
    setChoices(p.choices);
    setSheet(p.sheet);
  });
  useBusEvent<StatePayload>('game:state', (p) => {
    if (p.state !== 'SHEET_CLEAR') setChoices(null);
  });
  useBusEvent<ScorePayload>('game:score', (p) => setScore(p.score));
  useBusEvent<TimePayload>('game:time', (p) => setTime(p.remaining));

  if (!choices) return null;

  const pick = (id: string) => {
    godotSend('pick_upgrade', { id });
    setChoices(null);
  };

  return (
    <div className="cards-overlay">
      <h2>Sheet {sheet + 1} cleared — pick a power-up</h2>
      <div className="cards-status">
        <span className="cards-score">Score {score}</span>
        <span className="cards-time"><Icon name="hourglass" /> {Math.max(0, time).toFixed(1)}s</span>
        <button
          className="hud-buy-time"
          disabled={score < TIME_PURCHASE_COST}
          onClick={() => godotSend('buy_time')}
          aria-label={`Buy ${TIME_PURCHASE_SECONDS} seconds for ${TIME_PURCHASE_COST} score points`}
          title={score < TIME_PURCHASE_COST
            ? `Need ${TIME_PURCHASE_COST - score} more points`
            : `Spend ${TIME_PURCHASE_COST} points for ${TIME_PURCHASE_SECONDS} seconds`}
        >
          <Icon name="hourglass" /> +{TIME_PURCHASE_SECONDS}s <span>{TIME_PURCHASE_COST}</span>
        </button>
      </div>
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
