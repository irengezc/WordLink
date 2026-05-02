
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { generateWordChainData, ChainData } from './services/geminiService';
import { GameState, GameStatus, PhraseInfo, Difficulty, HistoryItem } from './types';
import WordDisplay from './components/WordDisplay';
import PhraseFlashcard from './components/PhraseFlashcard';

const MAX_WORDS = 8;
const HINT_COSTS = { EASY: 15, MEDIUM: 25, HARD: 40 };
const POOL_SIZE = 3;

// Pronunciation & Haptic Helpers
const pronounceWord = (word: string) => {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(word);
    utterance.rate = 1.0;
    utterance.pitch = 1.0;
    utterance.lang = 'en-US';
    window.speechSynthesis.speak(utterance);
  }
};

const triggerHaptic = (type: 'success' | 'warning' | 'light') => {
  if ('vibrate' in navigator) {
    if (type === 'success') navigator.vibrate([30]);
    if (type === 'warning') navigator.vibrate([50, 30, 50]);
    if (type === 'light') navigator.vibrate([10]);
  }
};

const playSoundEffect = (type: 'correct' | 'wrong' | 'hint') => {
  try {
    const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    const now = ctx.currentTime;
    if (type === 'correct') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(523.25, now);
      osc.frequency.exponentialRampToValueAtTime(880, now + 0.1);
      gain.gain.setValueAtTime(0.1, now);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.3);
      osc.start(now); osc.stop(now + 0.3);
    } else if (type === 'wrong') {
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(150, now);
      osc.frequency.linearRampToValueAtTime(50, now + 0.2);
      gain.gain.setValueAtTime(0.1, now);
      gain.gain.linearRampToValueAtTime(0.01, now + 0.2);
      osc.start(now); osc.stop(now + 0.2);
    } else if (type === 'hint') {
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(440, now);
      gain.gain.setValueAtTime(0.05, now);
      gain.gain.exponentialRampToValueAtTime(0.01, now + 0.1);
      osc.start(now); osc.stop(now + 0.1);
    }
  } catch (e) {}
};

const App: React.FC = () => {
  const [status, setStatus] = useState<GameStatus>(GameStatus.START);
  const [gameHistory, setGameHistory] = useState<HistoryItem[]>([]);
  const [selectedHistoryId, setSelectedHistoryId] = useState<string | null>(null);
  const [showInstallPrompt, setShowInstallPrompt] = useState(false);
  
  const [gamePool, setGamePool] = useState<Record<Difficulty, ChainData[]>>({
    EASY: [], MEDIUM: [], HARD: []
  });

  const [state, setState] = useState<GameState>({
    chain: [], explanations: [], currentIndex: 0, hintsUsed: 0,
    revealedLetters: 1, score: 100, isGameOver: false, isGameWon: false,
    userInput: '', feedback: 'none', history: [], difficulty: 'MEDIUM'
  });
  
  const [focusedHistoryIndex, setFocusedHistoryIndex] = useState<number | null>(null);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  
  const hiddenInputRef = useRef<HTMLInputElement>(null);
  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const activeWordRef = useRef<HTMLDivElement>(null);

  const refillPool = useCallback(async (difficulty: Difficulty) => {
    try {
      const data = await generateWordChainData(difficulty);
      setGamePool(prev => ({
        ...prev,
        [difficulty]: [...prev[difficulty], data]
      }));
    } catch (e) {
      console.error("Refill error", e);
    }
  }, []);

  useEffect(() => {
    for (let i = 0; i < POOL_SIZE; i++) refillPool('MEDIUM');
    refillPool('EASY');
    refillPool('HARD');

    // Detect if we should show the iOS install prompt
    const isIos = /iPad|iPhone|iPod/.test(navigator.userAgent);
    const isStandalone = (window.navigator as any).standalone || window.matchMedia('(display-mode: standalone)').matches;
    if (isIos && !isStandalone) {
      const hasPrompted = localStorage.getItem('ios_prompt_shown');
      if (!hasPrompted) {
        setTimeout(() => setShowInstallPrompt(true), 3000);
      }
    }
  }, [refillPool]);

  useEffect(() => {
    const handleVisualViewportChange = () => {
      if (window.visualViewport) {
        const h = window.innerHeight - window.visualViewport.height;
        const isKeyboardOpen = h > 60; 
        setKeyboardHeight(isKeyboardOpen ? h : 0);
        
        if (isKeyboardOpen) {
          setTimeout(() => {
            activeWordRef.current?.scrollIntoView({ behavior: 'auto', block: 'center' });
          }, 0);
        }
      }
    };
    window.visualViewport?.addEventListener('resize', handleVisualViewportChange);
    window.visualViewport?.addEventListener('scroll', handleVisualViewportChange);
    return () => {
      window.visualViewport?.removeEventListener('resize', handleVisualViewportChange);
      window.visualViewport?.removeEventListener('scroll', handleVisualViewportChange);
    };
  }, []);

  useEffect(() => {
    if (status === GameStatus.PLAYING) {
      const timer = setTimeout(() => hiddenInputRef.current?.focus(), 150);
      return () => clearTimeout(timer);
    }
  }, [status, state.currentIndex]);

  useEffect(() => {
    const saved = localStorage.getItem('wordlink_history_v2');
    if (saved) setGameHistory(JSON.parse(saved));
  }, []);

  const saveHistory = (item: HistoryItem) => {
    const newHistory = [item, ...gameHistory].slice(0, 20);
    setGameHistory(newHistory);
    localStorage.setItem('wordlink_history_v2', JSON.stringify(newHistory));
  };

  const startNewGame = async (difficulty: Difficulty) => {
    const currentPool = gamePool[difficulty];
    let data: ChainData;

    if (currentPool.length > 0) {
      data = currentPool[0];
      setGamePool(prev => ({ ...prev, [difficulty]: prev[difficulty].slice(1) }));
      refillPool(difficulty);
    } else {
      setStatus(GameStatus.LOADING);
      data = await generateWordChainData(difficulty);
    }

    setState({
      chain: data.chain, explanations: data.explanations,
      currentIndex: 0, hintsUsed: 0, revealedLetters: 1,
      score: difficulty === 'EASY' ? 100 : difficulty === 'MEDIUM' ? 80 : 50,
      isGameOver: false, isGameWon: false, userInput: '',
      feedback: 'none', history: [], difficulty
    });
    setFocusedHistoryIndex(null);
    setStatus(GameStatus.PLAYING);
  };

  const handleShare = async () => {
    triggerHaptic('light');
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Word Link',
          text: 'Check out this cool word guessing game I found!',
          url: window.location.href,
        });
      } catch (err) {
        console.error('Error sharing:', err);
      }
    } else {
      try {
        await navigator.clipboard.writeText(window.location.href);
        alert('Link copied to clipboard!');
      } catch (err) {
        console.error('Failed to copy link:', err);
      }
    }
  };

  const handleGuess = useCallback((suffix: string) => {
    const target = state.chain[state.currentIndex + 1];
    if (!target) return;
    
    const prefix = target.slice(0, state.revealedLetters);
    const fullGuess = (prefix + suffix).toUpperCase();

    if (fullGuess === target.toUpperCase()) {
      playSoundEffect('correct');
      triggerHaptic('success');
      pronounceWord(target);
      setState(prev => ({ ...prev, feedback: 'correct', userInput: suffix }));
      
      const points = Math.max(10, 50 - (state.revealedLetters - 1) * 10);
      const newPhrase = { 
        word1: state.chain[state.currentIndex], 
        word2: target, 
        explanation: state.explanations[state.currentIndex] 
      };
      
      setTimeout(() => {
        setFocusedHistoryIndex(null);
        setState(prev => {
          const isFinal = prev.currentIndex + 1 >= MAX_WORDS;
          const updatedHistory = [...prev.history, newPhrase];
          if (isFinal) {
            const finalScore = prev.score + points;
            saveHistory({ 
              id: Date.now().toString(), 
              date: new Date().toLocaleDateString() + ' ' + new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }), 
              score: finalScore, 
              difficulty: prev.difficulty, 
              chainLength: MAX_WORDS,
              phrases: updatedHistory
            });
            setStatus(GameStatus.RESULTS);
            return { ...prev, score: finalScore, isGameOver: true, isGameWon: true, feedback: 'none', history: updatedHistory, userInput: '' };
          } else {
            return { ...prev, currentIndex: prev.currentIndex + 1, revealedLetters: 1, userInput: '', score: prev.score + points, feedback: 'none', history: updatedHistory };
          }
        });
      }, 600);
    } else {
      if ((prefix + suffix).length >= target.length) {
        playSoundEffect('wrong');
        triggerHaptic('warning');
        setState(prev => ({ ...prev, feedback: 'wrong' }));
        setTimeout(() => setState(prev => ({ ...prev, feedback: 'none', userInput: '' })), 600);
      }
    }
  }, [state.chain, state.currentIndex, state.revealedLetters, state.explanations]);

  const useHint = () => {
    const cost = HINT_COSTS[state.difficulty];
    if (state.score < cost) return;
    const target = state.chain[state.currentIndex + 1];
    
    if (state.revealedLetters < target.length) {
      playSoundEffect('hint');
      triggerHaptic('light');
      const nextRevealedCount = state.revealedLetters + 1;
      
      setState(prev => ({ 
        ...prev, 
        revealedLetters: nextRevealedCount, 
        hintsUsed: prev.hintsUsed + 1, 
        score: Math.max(0, prev.score - cost),
        userInput: ''
      }));

      if (nextRevealedCount === target.length) {
        setTimeout(() => handleGuess(''), 300);
      }
    }
    hiddenInputRef.current?.focus();
  };

  const closeInstallPrompt = () => {
    setShowInstallPrompt(false);
    localStorage.setItem('ios_prompt_shown', 'true');
  };

  const renderHome = () => (
    <div className="flex flex-col items-center justify-center h-screen-ios p-6 text-center animate-in fade-in zoom-in duration-500 bg-slate-50 relative">
      <div className="mb-8 p-6 bg-indigo-600 rounded-[2rem] shadow-2xl rotate-3">
        <i className="fas fa-link text-7xl text-white"></i>
      </div>
      <h1 className="text-5xl font-black text-indigo-900 mb-2 tracking-tight">Word Link</h1>
      <p className="text-base text-indigo-700/60 mb-12 font-medium">Chain phrases, grow your vocabulary.</p>
      
      <div className="flex flex-col gap-4 w-full max-w-xs">
        <button onClick={() => { triggerHaptic('light'); setStatus(GameStatus.DIFFICULTY_SELECT); }} className="h-16 bg-indigo-600 text-white rounded-2xl font-black text-xl shadow-xl active:scale-95 transition-all flex items-center justify-center">Play Now</button>
        <button onClick={() => { triggerHaptic('light'); setStatus(GameStatus.HISTORY); }} className="h-16 bg-white text-indigo-600 border-2 border-indigo-100 rounded-2xl font-black text-lg active:scale-95 transition-all flex items-center justify-center">View History</button>
        
        <button onClick={handleShare} className="mt-4 flex items-center justify-center gap-2 text-indigo-500 font-bold hover:text-indigo-700 transition-colors">
          <i className="fas fa-arrow-up-from-bracket"></i>
          <span>Share with a Friend</span>
        </button>
      </div>

      {showInstallPrompt && (
        <div className="fixed bottom-10 left-6 right-6 z-50 animate-in slide-in-from-bottom-10">
          <div className="bg-white rounded-[2rem] shadow-2xl p-6 border-2 border-indigo-100 relative">
            <button onClick={closeInstallPrompt} className="absolute top-4 right-4 text-slate-300">
              <i className="fas fa-times"></i>
            </button>
            <div className="flex items-start gap-4 pr-6">
              <div className="w-12 h-12 bg-indigo-600 rounded-xl flex items-center justify-center flex-shrink-0">
                <i className="fas fa-link text-white text-xl"></i>
              </div>
              <div className="text-left">
                <p className="font-black text-indigo-900 leading-tight mb-1">Install Word Link</p>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Tap <i className="fas fa-arrow-up-from-bracket text-indigo-500 mx-0.5"></i> then <span className="font-bold text-slate-700 italic">"Add to Home Screen"</span> for the full experience.
                </p>
              </div>
            </div>
            <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 w-4 h-4 bg-white border-b-2 border-r-2 border-indigo-100 rotate-45"></div>
          </div>
        </div>
      )}
      
      <div className="absolute bottom-10 text-[10px] text-slate-300 font-bold uppercase tracking-widest px-8">
        Designed for iOS • Add to Home Screen for the best experience
      </div>
    </div>
  );

  const renderDifficulty = () => (
    <div className="flex flex-col items-center justify-center h-screen-ios p-6 animate-in slide-in-from-bottom-10">
      <h2 className="text-3xl font-black text-indigo-900 mb-8">Select Level</h2>
      <div className="grid grid-cols-1 gap-4 w-full max-w-xs">
        {(['EASY', 'MEDIUM', 'HARD'] as Difficulty[]).map(d => (
          <button key={d} onClick={() => startNewGame(d)} className="p-6 bg-white border-2 border-slate-100 rounded-3xl active:border-indigo-500 transition-all text-left group">
            <p className="text-[10px] font-black text-indigo-400 mb-1 uppercase tracking-widest">{d}</p>
            <p className="text-slate-600 text-sm font-semibold">
              {d === 'EASY' ? 'Common two-word phrases.' : d === 'MEDIUM' ? 'Standard expressions.' : 'Idioms & abstract chains.'}
              {gamePool[d].length > 0 && <span className="ml-2 inline-flex h-2 w-2 rounded-full bg-emerald-400 animate-pulse"></span>}
            </p>
          </button>
        ))}
        <button onClick={() => setStatus(GameStatus.START)} className="mt-6 text-slate-400 font-bold py-2 active:scale-95">Back to Menu</button>
      </div>
    </div>
  );

  const renderHistory = () => {
    const selectedItem = gameHistory.find(h => h.id === selectedHistoryId);

    return (
      <div className="flex flex-col h-screen-ios bg-white overflow-hidden">
        <div className="p-4 pt-safe-nav border-b border-slate-100 flex items-center justify-between bg-white/95 backdrop-blur-md sticky top-0 z-50">
          <div className="flex items-center gap-4">
            <button onClick={() => selectedHistoryId ? setSelectedHistoryId(null) : setStatus(GameStatus.START)} className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 active:scale-90 transition-all">
              <i className="fas fa-arrow-left"></i>
            </button>
            <h2 className="text-2xl font-black text-slate-800">{selectedHistoryId ? 'Round Detail' : 'History'}</h2>
          </div>
          {!selectedHistoryId && gameHistory.length > 0 && (
            <button onClick={() => { if(confirm('Clear all history?')) { setGameHistory([]); localStorage.removeItem('wordlink_history_v2'); } }} className="text-rose-500 text-xs font-bold uppercase tracking-widest">Clear</button>
          )}
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-4 no-scrollbar">
          {selectedHistoryId && selectedItem ? (
            <div className="animate-in fade-in slide-in-from-right-4">
              <div className="mb-6 p-4 bg-indigo-50 rounded-2xl">
                <p className="text-[10px] font-bold text-indigo-400 uppercase mb-1">{selectedItem.date}</p>
                <p className="text-2xl font-black text-indigo-900">Score: {selectedItem.score}</p>
              </div>
              <div className="space-y-3 pb-safe">
                {selectedItem.phrases.map((p, i) => (
                  <div key={i} className="bg-white border border-slate-100 rounded-2xl p-4 shadow-sm">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="font-bold text-slate-400">{p.word1}</span>
                      <i className="fas fa-arrow-right text-[10px] text-indigo-300"></i>
                      <span className="font-black text-indigo-600">{p.word2}</span>
                    </div>
                    <p className="text-xs text-slate-500 italic">"{p.explanation}"</p>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="pb-safe">
              {gameHistory.length === 0 ? (
                <div className="flex flex-col items-center justify-center mt-20 text-slate-400">
                  <i className="fas fa-history text-4xl mb-4 opacity-20"></i>
                  <p className="italic">No games played yet!</p>
                </div>
              ) : (
                gameHistory.map(item => (
                  <button key={item.id} onClick={() => setSelectedHistoryId(item.id)} className="w-full mb-3 p-5 bg-slate-50 rounded-3xl border border-slate-100 flex justify-between items-center active:scale-[0.98] transition-all text-left">
                    <div>
                      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">{item.date}</p>
                      <div className="flex items-center gap-2">
                         <span className="px-2 py-0.5 bg-indigo-600 text-white text-[8px] font-black rounded uppercase">{item.difficulty}</span>
                         <span className="text-slate-700 font-black">Round {item.chainLength}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Score</p>
                      <p className="font-black text-indigo-600 text-2xl tabular-nums">{item.score}</p>
                    </div>
                  </button>
                ))
              )}
            </div>
          )}
        </div>
      </div>
    );
  };

  const renderPlaying = () => {
    const currentWord = state.chain[state.currentIndex];
    const targetWord = state.chain[state.currentIndex + 1];
    const progress = (state.currentIndex / MAX_WORDS) * 100;
    const maxInputLength = targetWord ? targetWord.length - state.revealedLetters : 0;

    return (
      <div className="flex flex-col h-screen-ios max-w-lg mx-auto bg-slate-50 relative overflow-hidden" onClick={() => hiddenInputRef.current?.focus()}>
        <input 
          ref={hiddenInputRef} 
          type="text" 
          className="fixed -top-40 opacity-0 pointer-events-none" 
          autoFocus 
          value={state.userInput} 
          onChange={(e) => {
            const val = e.target.value.toUpperCase().slice(0, maxInputLength);
            if (state.feedback === 'none') {
              setState(prev => ({ ...prev, userInput: val }));
              if (targetWord && val.length === maxInputLength) {
                handleGuess(val);
              }
            }
          }} 
          autoComplete="off" 
          spellCheck="false" 
        />
        
        <div className="p-4 pt-safe-nav flex items-center justify-between bg-white/95 backdrop-blur-lg sticky top-0 z-40 shadow-sm border-b border-slate-100">
          <button onClick={(e) => { e.stopPropagation(); triggerHaptic('light'); setStatus(GameStatus.START); }} className="w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 active:scale-90">
            <i className="fas fa-times"></i>
          </button>
          <div className="flex flex-col items-center flex-1">
            <div className="flex items-center gap-1 mb-1">
              <i className="fas fa-star text-amber-400 text-[10px]"></i>
              <span className="font-black text-indigo-900 text-sm tabular-nums">{state.score}</span>
            </div>
            <div className="w-full px-4 max-w-[140px]">
              <div className="h-1.5 bg-slate-100 rounded-full overflow-hidden border border-slate-50">
                <div className="h-full bg-indigo-500 transition-all duration-700 ease-out" style={{ width: `${progress}%` }}></div>
              </div>
            </div>
          </div>
          <button onClick={(e) => { e.stopPropagation(); useHint(); }} disabled={state.score < HINT_COSTS[state.difficulty]} className="px-4 h-10 bg-amber-50 text-amber-600 rounded-2xl font-black text-[11px] border border-amber-100 uppercase active:scale-90 disabled:opacity-30 transition-all">
            Hint
          </button>
        </div>

        <div ref={scrollContainerRef} className="flex-1 overflow-y-auto p-4 pt-8 space-y-4 no-scrollbar relative" style={{ paddingBottom: keyboardHeight > 0 ? `${keyboardHeight + 60}px` : '120px' }}>
          <div className="relative flex flex-col items-center w-full">
            {state.history.map((info, idx) => {
              const fromTop = state.history.length - idx;
              const isFocused = focusedHistoryIndex === idx;
              return (
                <div 
                  key={idx} 
                  onClick={(e) => { e.stopPropagation(); triggerHaptic('light'); setFocusedHistoryIndex(idx === focusedHistoryIndex ? null : idx); }}
                  style={{ 
                    zIndex: isFocused ? 100 : idx + 10, 
                    width: '100%',
                    transform: `translateY(-${fromTop * 8}px) scale(${isFocused ? 1.05 : 1 - (fromTop * 0.015)})`, 
                    opacity: isFocused ? 1 : 1 / (fromTop * 0.4 + 0.6),
                    transition: 'all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
                  }} 
                  className={`mb-[-60px] cursor-pointer ${isFocused ? 'shadow-2xl' : ''}`}
                >
                  <PhraseFlashcard info={info} isLatest={idx === state.history.length - 1} />
                </div>
              );
            })}
          </div>

          {state.currentIndex < MAX_WORDS && (
            <div ref={activeWordRef} className="animate-in slide-in-from-bottom-12 duration-500 pt-16">
              <WordDisplay 
                firstWord={currentWord} 
                targetWord={targetWord} 
                revealedCount={state.revealedLetters} 
                userInput={state.userInput} 
                feedback={state.feedback} 
                isFocused={true} 
              />
            </div>
          )}
        </div>
        
        <div className="absolute left-0 right-0 flex justify-center pointer-events-none z-30 px-6" style={{ bottom: keyboardHeight > 0 ? `${keyboardHeight + 12}px` : '24px' }}>
          <div className="bg-white/80 backdrop-blur-md px-6 py-2 rounded-full border border-indigo-100 shadow-lg text-[11px] font-black text-slate-500 uppercase tracking-widest animate-pulse flex items-center gap-2">
            <i className="fas fa-keyboard text-indigo-400"></i>
            {state.revealedLetters > 0 ? `Starts with "${targetWord?.slice(0, state.revealedLetters)}"` : 'Type to complete link'}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen-ios bg-slate-50 overflow-hidden select-none">
      {status === GameStatus.START && renderHome()}
      {status === GameStatus.DIFFICULTY_SELECT && renderDifficulty()}
      {status === GameStatus.HISTORY && renderHistory()}
      {status === GameStatus.LOADING && (
        <div className="flex flex-col items-center justify-center h-screen-ios p-6">
          <div className="relative w-20 h-20">
            <div className="absolute inset-0 border-[6px] border-indigo-100 rounded-full"></div>
            <div className="absolute inset-0 border-[6px] border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
          </div>
          <h2 className="text-2xl font-black text-indigo-900 mt-8 tracking-tight">Linking words...</h2>
          <p className="text-xs text-indigo-400 font-black uppercase tracking-widest mt-3 animate-pulse">Consulting the Lexicon</p>
        </div>
      )}
      {status === GameStatus.PLAYING && renderPlaying()}
      {status === GameStatus.RESULTS && (
        <div className="flex flex-col items-center justify-center h-screen-ios p-6 text-center animate-in zoom-in bg-emerald-50">
          <div className="w-28 h-28 bg-white rounded-[2rem] flex items-center justify-center mb-8 shadow-2xl border-4 border-emerald-100 rotate-12">
            <i className="fas fa-crown text-6xl text-amber-400"></i>
          </div>
          <h1 className="text-5xl font-black text-emerald-900 mb-2">Round Clear!</h1>
          <p className="text-emerald-700 font-bold mb-10 opacity-70">Expert chain completed.</p>
          <div className="bg-white p-8 rounded-[2.5rem] shadow-xl mb-12 w-full max-w-xs border-b-[12px] border-emerald-200">
            <div className="text-6xl font-black text-indigo-600 tabular-nums">{state.score}</div>
            <div className="text-[10px] font-bold text-slate-400 uppercase tracking-[0.2em] mt-3">Final Score</div>
          </div>
          <button onClick={() => { triggerHaptic('light'); setStatus(GameStatus.START); }} className="h-16 w-full max-w-xs bg-indigo-600 text-white rounded-2xl font-black text-xl shadow-xl active:scale-95 transition-all flex items-center justify-center">Great!</button>
        </div>
      )}
      
      <style>{`
        .no-scrollbar::-webkit-scrollbar { display: none; }
        .no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
        .pt-safe-nav { padding-top: calc(env(safe-area-inset-top) + 0.5rem); }
        .pb-safe { padding-bottom: env(safe-area-inset-bottom); }
      `}</style>
    </div>
  );
};

export default App;
