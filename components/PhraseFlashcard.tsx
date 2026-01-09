
import React, { useState } from 'react';
import { PhraseInfo } from '../types';

interface PhraseFlashcardProps {
  info: PhraseInfo;
  isLatest?: boolean;
}

const PhraseFlashcard: React.FC<PhraseFlashcardProps> = ({ info, isLatest }) => {
  const [isFlipped, setIsFlipped] = useState(false);

  return (
    <div 
      className={`relative w-full h-24 perspective-1000 cursor-pointer transition-all duration-500 mb-4 ${isLatest ? 'animate-in zoom-in slide-in-from-bottom-4' : ''}`}
      onClick={() => setIsFlipped(!isFlipped)}
    >
      <div className={`relative w-full h-full transition-transform duration-500 transform-style-3d ${isFlipped ? 'rotate-y-180' : ''}`}>
        {/* Front */}
        <div className="absolute inset-0 backface-hidden bg-white border-2 border-indigo-100 rounded-2xl shadow-sm flex items-center justify-center p-4">
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold text-slate-500">{info.word1}</span>
            <div className="w-4 h-4 rounded-full bg-indigo-100 flex items-center justify-center">
              <i className="fas fa-link text-[10px] text-indigo-400"></i>
            </div>
            <span className="text-xl font-black text-indigo-600">{info.word2}</span>
          </div>
          <div className="absolute top-2 right-3 text-[10px] text-slate-300 uppercase font-bold tracking-tighter">Tap to flip</div>
        </div>

        {/* Back */}
        <div className="absolute inset-0 backface-hidden bg-indigo-600 text-white border-2 border-indigo-700 rounded-2xl shadow-sm flex items-center justify-center p-4 rotate-y-180">
          <p className="text-sm font-medium text-center line-clamp-3 italic">
            "{info.explanation}"
          </p>
        </div>
      </div>
      
      <style>{`
        .perspective-1000 { perspective: 1000px; }
        .transform-style-3d { transform-style: preserve-3d; }
        .backface-hidden { backface-visibility: hidden; }
        .rotate-y-180 { transform: rotateY(180deg); }
      `}</style>
    </div>
  );
};

export default PhraseFlashcard;
