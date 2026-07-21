import { useState } from 'react';
import { useBusEvent } from '../bus';
import { godotSend } from '../godot/bridge';
import { BASE_TIME } from '../game/constants';
import { POWERUPS } from '../meta/catalog';
import { buildLoadout, bank } from '../meta/store';
import { Shop } from './Shop';
import type {
  GameState,
  StatePayload,
  ScorePayload,
  TimePayload,
  RunOverPayload,
  LoadoutPayload,
} from '../game/events';

export function Hud() {
  const [state, setState] = useState<GameState>('IDLE');
  const [score, setScore] = useState(0);
  const [time, setTime] = useState(BASE_TIME);
  const [last, setLast] = useState<RunOverPayload | null>(null);
  const [loadout, setLoadout] = useState<LoadoutPayload>({ ricochet: 0, area: 0, autoclick: 0 });

  useBusEvent<StatePayload>('game:state', (p) => setState(p.state));
  useBusEvent<ScorePayload>('game:score', (p) => setScore(p.score));
  useBusEvent<TimePayload>('game:time', (p) => setTime(p.remaining));
  useBusEvent<RunOverPayload>('game:run_over', (p) => {
    setLast(p);
    bank(p.currencyEarned);
  });
  useBusEvent<LoadoutPayload>('game:loadout', (p) => setLoadout(p));

  return (
    <div className="hud">
      {state === 'PLAYING' && (
        <div className="hud-play">
          <div className="hud-time">
            <div
              className="hud-time-bar"
              style={{ width: `${Math.min(100, Math.max(0, (time / BASE_TIME) * 100))}%` }}
            />
          </div>
          <div className="hud-score">{score}</div>
          <div className="hud-loadout">
            {loadout.ricochet > 0 && <span>{POWERUPS.P_RICOCHET.icon}{loadout.ricochet}</span>}
            {loadout.area > 0 && <span>{POWERUPS.P_AREA.icon}{loadout.area}</span>}
            {loadout.autoclick > 0 && <span>{POWERUPS.P_AUTOCLICK.icon}{loadout.autoclick}</span>}
          </div>
        </div>
      )}

      {state === 'IDLE' && (
        <div className="panel">
          <h1>Bubble Roguelite</h1>
          <Shop />
          <button onClick={() => godotSend('start_run', buildLoadout())}>Start</button>
        </div>
      )}

      {state === 'GAME_OVER' && (
        <div className="panel">
          <h1>Time!</h1>
          <p>
            Score: {last?.score ?? score} · earned 🫧 {last?.currencyEarned ?? 0}
          </p>
          <Shop />
          <button onClick={() => godotSend('restart', buildLoadout())}>Play again</button>
        </div>
      )}
    </div>
  );
}
