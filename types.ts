
export type Difficulty = 'EASY' | 'MEDIUM' | 'HARD';

export interface PhraseInfo {
  word1: string;
  word2: string;
  explanation: string;
}

export interface HistoryItem {
  id: string;
  date: string;
  score: number;
  difficulty: Difficulty;
  chainLength: number;
  phrases: PhraseInfo[];
}

export interface GameState {
  chain: string[];
  explanations: string[];
  currentIndex: number;
  hintsUsed: number;
  revealedLetters: number;
  score: number;
  isGameOver: boolean;
  isGameWon: boolean;
  userInput: string;
  feedback: 'none' | 'correct' | 'wrong';
  history: PhraseInfo[];
  difficulty: Difficulty;
}

export enum GameStatus {
  START = 'START',
  DIFFICULTY_SELECT = 'DIFFICULTY_SELECT',
  PLAYING = 'PLAYING',
  RESULTS = 'RESULTS',
  LOADING = 'LOADING',
  HISTORY = 'HISTORY'
}
