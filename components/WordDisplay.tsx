
import React from 'react';

interface WordDisplayProps {
  firstWord: string;
  targetWord: string;
  revealedCount: number;
  userInput: string;
  feedback: 'none' | 'correct' | 'wrong';
  isFocused: boolean;
}

const WordDisplay: React.FC<WordDisplayProps> = ({ 
  firstWord, 
  targetWord, 
  revealedCount,
  userInput,
  feedback,
  isFocused
}) => {
  const letters = (targetWord || '').split('');
  // User input represents only the characters typed AFTER the revealed prefix
  const userLetters = (userInput || '').split('');

  return (
    <div className="flex flex-col items-center gap-3 w-full max-w-md mx-auto">
      {/* First Word Card */}
      <div className={`bg-white rounded-xl shadow-sm p-4 w-full text-center border border-slate-100 transition-all duration-700 ${feedback === 'correct' ? 'scale-75 opacity-0 -translate-y-12' : ''}`}>
        <span className="text-[8px] font-bold text-slate-300 uppercase tracking-widest mb-1 block">Link Word</span>
        <h2 className="text-2xl font-black text-slate-500 tracking-tight">{firstWord}</h2>
      </div>

      {/* Target Word Placeholder */}
      <div className={`bg-white rounded-3xl shadow-xl p-8 w-full border-2 transition-all duration-300 relative ${
        feedback === 'correct' ? 'border-emerald-400 bg-emerald-50 scale-105' : 
        feedback === 'wrong' ? 'border-rose-400 shake bg-rose-50' : 
        isFocused ? 'border-indigo-200 ring-4 ring-indigo-50/50' : 'border-slate-100'
      }`}>
        <div className="flex justify-center gap-2 overflow-x-auto py-1">
          {letters.map((char, i) => {
            const isPrefixRevealed = i < revealedCount;
            // If it's the prefix, show the target char. 
            // Otherwise, show what the user typed for this relative position.
            const userChar = isPrefixRevealed ? null : userLetters[i - revealedCount];
            
            const displayChar = isPrefixRevealed ? char : (userChar || '');
            const isActiveCursor = isFocused && !isPrefixRevealed && (i === revealedCount + userLetters.length);
            
            return (
              <div 
                key={i} 
                className={`w-9 h-11 md:w-11 md:h-14 flex items-center justify-center rounded-xl border-b-4 text-2xl font-black transition-all duration-200 relative ${
                  isPrefixRevealed 
                    ? 'border-indigo-600 bg-indigo-50 text-indigo-700' 
                    : userChar 
                      ? 'border-indigo-300 bg-white text-slate-800'
                      : 'border-slate-200 bg-slate-50 text-transparent'
                }`}
              >
                {displayChar}
                {isActiveCursor && (
                  <div className="absolute bottom-2 w-5 h-1 bg-indigo-400 animate-pulse rounded-full"></div>
                )}
              </div>
            );
          })}
        </div>
        <div className="flex justify-center mt-4">
          <p className={`text-[10px] font-black uppercase tracking-widest px-4 py-1 rounded-full ${
            feedback === 'wrong' ? 'text-rose-500 bg-rose-100' : 
            feedback === 'correct' ? 'text-emerald-600 bg-emerald-100' : 
            'text-indigo-300 bg-slate-50'
          }`}>
            {feedback === 'wrong' ? 'Incorrect!' : feedback === 'correct' ? 'Correct!' : `${targetWord.length} letters`}
          </p>
        </div>
      </div>
    </div>
  );
};

export default WordDisplay;
