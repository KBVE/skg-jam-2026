export type GameState = 'IDLE' | 'PLAYING' | 'SHEET_CLEAR' | 'GAME_OVER';

export interface StatePayload {
  state: GameState;
}
export interface ScorePayload {
  score: number;
}
export interface TimePayload {
  remaining: number;
}
export interface PopPayload {
  kind: string;
  points: number;
  x: number;
  y: number;
}
export interface RunOverPayload {
  score: number;
  currencyEarned: number;
}
export interface SheetClearPayload {
  sheet: number;
  choices: string[];
}
export interface LoadoutPayload {
  ricochet: number;
  area: number;
  autoclick: number;
}
