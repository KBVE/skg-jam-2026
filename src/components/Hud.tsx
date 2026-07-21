import { useState } from 'react';
import { useBusEvent } from '../bus';
import { godotSend } from '../godot/bridge';
import { BASE_TIME, TIME_PURCHASE_COST, TIME_PURCHASE_SECONDS } from '../game/constants';
import { POWERUPS } from '../meta/catalog';
import { buildLoadout, bank } from '../meta/store';
import { playPop, isMuted, toggleMute } from '../game/sfx';
import { Shop } from './Shop';
import { Icon } from './Icon';
import type {
  PopPayload,
  GameState,
  StatePayload,
  ScorePayload,
  TimePayload,
  RunOverPayload,
  LoadoutPayload,
} from '../game/events';

const BEST_KEY = 'bubble_best';
function readBest(): number {
  try {
    return Number(localStorage.getItem(BEST_KEY)) || 0;
  } catch {
    return 0;
  }
}
function writeBest(v: number): void {
  try {
    localStorage.setItem(BEST_KEY, String(v));
  } catch {
    /* storage unavailable */
  }
}

export function Hud() {
  const [state, setState] = useState<GameState>('IDLE');
  const [score, setScore] = useState(0);
  const [time, setTime] = useState(BASE_TIME);
  const [last, setLast] = useState<RunOverPayload | null>(null);
  const [loadout, setLoadout] = useState<LoadoutPayload>({ ricochet: 0, area: 0, autoclick: 0 });
  const [muted, setMuted] = useState(isMuted());
  const [best, setBest] = useState(readBest());
  const [beatBest, setBeatBest] = useState(false);

  useBusEvent<StatePayload>('game:state', (p) => setState(p.state));
  useBusEvent<ScorePayload>('game:score', (p) => setScore(p.score));
  useBusEvent<TimePayload>('game:time', (p) => setTime(p.remaining));
  useBusEvent<RunOverPayload>('game:run_over', (p) => {
    setLast(p);
    bank(p.currencyEarned);
    const prev = readBest();
    if (p.score > prev) {
      writeBest(p.score);
      setBest(p.score);
      setBeatBest(true);
    } else {
      setBeatBest(false);
    }
  });
  useBusEvent<LoadoutPayload>('game:loadout', (p) => setLoadout(p));
  useBusEvent<PopPayload>('game:pop', (p) => playPop(p.points));

  const low = time <= 12; // urgency threshold

  return (
    <div className="hud">
      {state === 'PLAYING' && (
        <>
          <div className={`hud-play${low ? ' low' : ''}`}>
            <div className="hud-clock">{Math.max(0, time).toFixed(1)}s</div>
            <div className="hud-time">
              <div
                className="hud-time-bar"
                style={{ width: `${Math.min(100, Math.max(0, (time / BASE_TIME) * 100))}%` }}
              />
            </div>
            <div className="hud-score" key={score}>{score}</div>
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
            <div className="hud-loadout">
              {loadout.ricochet > 0 && <span><Icon name={POWERUPS.P_RICOCHET.icon} />{loadout.ricochet}</span>}
              {loadout.area > 0 && <span><Icon name={POWERUPS.P_AREA.icon} />{loadout.area}</span>}
              {loadout.autoclick > 0 && <span><Icon name={POWERUPS.P_AUTOCLICK.icon} />{loadout.autoclick}</span>}
            </div>
          </div>
          <MuteToggle muted={muted} onToggle={() => setMuted(toggleMute())} />
        </>
      )}

      {state === 'IDLE' && (
        <div className="panel">
          <MuteToggle muted={muted} onToggle={() => setMuted(toggleMute())} />
          <h1>Bubble Roguelite</h1>
          <p className="panel-tag">Pop every bubble before the timer runs out.</p>
          <p className="panel-how">Click bubbles to pop · clear the sheet · pick a power-up · go deeper</p>
          {best > 0 && <p className="panel-best">Best {best}</p>}
          <Shop />
          <button onClick={() => godotSend('start_run', buildLoadout())}>Start</button>
        </div>
      )}

      {state === 'GAME_OVER' && (
        <div className="panel">
          <MuteToggle muted={muted} onToggle={() => setMuted(toggleMute())} />
          <h1>Time!</h1>
          {beatBest && <p className="panel-newbest">✨ New best!</p>}
          <p>
            Score: {last?.score ?? score} · earned <Icon name="droplet" /> {last?.currencyEarned ?? 0}
          </p>
          {best > 0 && <p className="panel-best">Best {best}</p>}
          <Shop />
          <button onClick={() => godotSend('restart', buildLoadout())}>Play again</button>
        </div>
      )}
    </div>
  );
}

function MuteToggle({ muted, onToggle }: { muted: boolean; onToggle: () => void }) {
  return (
    <button
      className="mute-toggle"
      onClick={onToggle}
      aria-label={muted ? 'Unmute sound' : 'Mute sound'}
      aria-pressed={muted}
      title={muted ? 'Unmute' : 'Mute'}
    >
      <Icon name={muted ? 'volume-x' : 'volume'} />
    </button>
  );
}
