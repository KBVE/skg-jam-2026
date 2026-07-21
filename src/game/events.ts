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
  points: number;
}
export interface RunOverPayload {
  score: number;
  currencyEarned: number;
}
