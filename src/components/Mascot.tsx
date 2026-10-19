import React from 'react';
import type { CoachMood } from '../gamification/coach';

interface MascotProps {
  stage?: number; // 1 to 5
  mood?: CoachMood;
  size?: number | string;
  className?: string;
  showName?: boolean;
}

export const Mascot: React.FC<MascotProps> = ({
  stage = 1,
  mood = 'happy',
  size = 48,
  className = '',
  showName = false,
}) => {
  const s = Math.min(5, Math.max(1, stage));

  // Render SVG based on stage and mood
  const renderMascotBody = () => {
    switch (s) {
      case 5: // Fénix
        return (
          <g>
            {/* Phoenix Wings */}
            <path
              d="M12 42 C4 30, 8 16, 22 24 C14 34, 18 42, 12 42 Z"
              fill="url(#phoenixGradL)"
              filter="drop-shadow(0px 0px 4px rgba(239, 68, 68, 0.4))"
            />
            <path
              d="M52 42 C60 30, 56 16, 42 24 C50 34, 46 42, 52 42 Z"
              fill="url(#phoenixGradR)"
              filter="drop-shadow(0px 0px 4px rgba(239, 68, 68, 0.4))"
            />
            {/* Tail feathers */}
            <path d="M26 54 Q32 62 38 54 Q32 58 26 54 Z" fill="#ef4444" />
            {/* Main Body */}
            <path
              d="M32 10 C24 18, 18 28, 20 42 C22 52, 42 52, 44 42 C46 28, 40 18, 32 10 Z"
              fill="url(#mascotGrad)"
            />
            {/* Inner Fire */}
            <path
              d="M32 18 C27 24, 24 32, 26 42 C28 48, 36 48, 38 42 C40 32, 37 24, 32 18 Z"
              fill="url(#mascotInnerGrad)"
            />
            {/* Phoenix Crest / Crown */}
            <path d="M32 6 L28 14 L32 11 L36 14 Z" fill="#fbbf24" />
            <circle cx="32" cy="5" r="2.5" fill="#f59e0b" />
          </g>
        );

      case 4: // Fogata
        return (
          <g>
            {/* Campfire logs */}
            <rect x="18" y="52" width="28" height="6" rx="3" fill="#78350f" transform="rotate(-10 32 55)" />
            <rect x="18" y="52" width="28" height="6" rx="3" fill="#92400e" transform="rotate(10 32 55)" />
            {/* Sparks */}
            <circle cx="16" cy="20" r="1.5" fill="#fbbf24" />
            <circle cx="48" cy="18" r="1.5" fill="#fbbf24" />
            <circle cx="44" cy="10" r="1" fill="#f59e0b" />
            {/* Big Flame Body */}
            <path
              d="M32 8 C22 18, 14 30, 16 44 C18 54, 46 54, 48 44 C50 30, 42 18, 32 8 Z"
              fill="url(#mascotGrad)"
            />
            {/* Side Flame Tendrils */}
            <path d="M18 36 C12 32, 14 24, 20 28 C18 32, 18 34, 18 36 Z" fill="#f97316" />
            <path d="M46 36 C52 32, 50 24, 44 28 C46 32, 46 34, 46 36 Z" fill="#f97316" />
            {/* Inner Flame */}
            <path
              d="M32 18 C26 26, 22 34, 24 44 C26 50, 38 50, 40 44 C42 34, 38 26, 32 18 Z"
              fill="url(#mascotInnerGrad)"
            />
          </g>
        );

      case 3: // Fueguito
        return (
          <g>
            {/* Sparks */}
            <circle cx="20" cy="16" r="1.5" fill="#fbbf24" />
            <circle cx="44" cy="14" r="1.5" fill="#f59e0b" />
            {/* Medium Flame Body */}
            <path
              d="M32 10 C22 20, 16 32, 18 44 C20 54, 44 54, 46 44 C48 32, 42 20, 32 10 Z"
              fill="url(#mascotGrad)"
            />
            {/* Side Flame */}
            <path d="M44 34 C49 30, 47 24, 42 27 C44 30, 44 32, 44 34 Z" fill="#f97316" />
            {/* Inner Flame */}
            <path
              d="M32 20 C26 28, 22 36, 24 44 C26 50, 38 50, 40 44 C42 36, 38 28, 32 20 Z"
              fill="url(#mascotInnerGrad)"
            />
          </g>
        );

      case 2: // Llamita
        return (
          <g>
            {/* Little Flame Body */}
            <path
              d="M32 12 C24 22, 18 32, 20 44 C22 52, 42 52, 44 44 C46 32, 40 22, 32 12 Z"
              fill="url(#mascotGrad)"
            />
            {/* Inner Flame */}
            <path
              d="M32 22 C26 29, 24 36, 26 44 C27 49, 37 49, 38 44 C40 36, 38 29, 32 22 Z"
              fill="url(#mascotInnerGrad)"
            />
          </g>
        );

      case 1: // Brasita
      default:
        return (
          <g>
            {/* Small glowing ember */}
            <circle cx="32" cy="38" r="16" fill="url(#mascotGrad)" />
            <path
              d="M32 18 C28 26, 20 32, 20 38 C20 46, 44 46, 44 38 C44 32, 36 26, 32 18 Z"
              fill="url(#mascotGrad)"
            />
            <circle cx="32" cy="39" r="10" fill="url(#mascotInnerGrad)" />
            <circle cx="42" cy="24" r="1.5" fill="#fbbf24" opacity="0.8" />
          </g>
        );
    }
  };

  // Render face eyes and mouth according to mood
  const renderFace = () => {
    const eyeY = s === 1 ? 36 : s === 5 ? 32 : 34;
    const mouthY = eyeY + 7;

    switch (mood) {
      case 'proud':
        return (
          <g>
            {/* Sunglasses / cool look */}
            <rect x="23" y={eyeY - 4} width="8" height="6" rx="2" fill="#18181b" />
            <rect x="33" y={eyeY - 4} width="8" height="6" rx="2" fill="#18181b" />
            <line x1="31" y1={eyeY - 1} x2="33" y2={eyeY - 1} stroke="#18181b" strokeWidth="2" />
            {/* Smile with tongue */}
            <path d={`M27 ${mouthY} Q32 ${mouthY + 4} 37 ${mouthY}`} stroke="#78350f" strokeWidth="2" fill="none" strokeLinecap="round" />
            <path d={`M29 ${mouthY + 1} Q32 ${mouthY + 5} 35 ${mouthY + 1}`} fill="#ef4444" />
          </g>
        );

      case 'worried':
        return (
          <g>
            {/* Worried eyes */}
            <ellipse cx="26" cy={eyeY} rx="2.5" ry="3.5" fill="#18181b" />
            <ellipse cx="38" cy={eyeY} rx="2.5" ry="3.5" fill="#18181b" />
            {/* Worried brows */}
            <line x1="23" y1={eyeY - 5} x2="28" y2={eyeY - 3} stroke="#78350f" strokeWidth="1.5" strokeLinecap="round" />
            <line x1="41" y1={eyeY - 5} x2="36" y2={eyeY - 3} stroke="#78350f" strokeWidth="1.5" strokeLinecap="round" />
            {/* Sweat drop */}
            <path d="M43 28 Q45 32 43 34 Q41 32 43 28 Z" fill="#38bdf8" />
            {/* Wavy mouth */}
            <path d={`M28 ${mouthY} Q30 ${mouthY - 2} 32 ${mouthY} Q34 ${mouthY + 2} 36 ${mouthY}`} stroke="#78350f" strokeWidth="1.8" fill="none" strokeLinecap="round" />
          </g>
        );

      case 'rest':
        return (
          <g>
            {/* Sleeping / resting eyes (arcs) */}
            <path d={`M24 ${eyeY} Q27 ${eyeY + 3} 30 ${eyeY}`} stroke="#18181b" strokeWidth="2" fill="none" strokeLinecap="round" />
            <path d={`M34 ${eyeY} Q37 ${eyeY + 3} 40 ${eyeY}`} stroke="#18181b" strokeWidth="2" fill="none" strokeLinecap="round" />
            {/* ZZZ */}
            <text x="44" y="24" fontSize="8" fontWeight="bold" fill="#a855f7" fontFamily="sans-serif">z</text>
            <text x="49" y="18" fontSize="10" fontWeight="bold" fill="#a855f7" fontFamily="sans-serif">Z</text>
            {/* Gentle smile */}
            <path d={`M28 ${mouthY} Q32 ${mouthY + 2} 36 ${mouthY}`} stroke="#78350f" strokeWidth="1.8" fill="none" strokeLinecap="round" />
          </g>
        );

      case 'recover':
        return (
          <g>
            {/* Determined / energized eyes */}
            <ellipse cx="26" cy={eyeY} rx="2.5" ry="3.5" fill="#18181b" />
            <circle cx="27" cy={eyeY - 1} r="1" fill="#ffffff" />
            <ellipse cx="38" cy={eyeY} rx="2.5" ry="3.5" fill="#18181b" />
            <circle cx="39" cy={eyeY - 1} r="1" fill="#ffffff" />
            {/* Determined brows */}
            <line x1="23" y1={eyeY - 3} x2="28" y2={eyeY - 5} stroke="#78350f" strokeWidth="1.5" strokeLinecap="round" />
            <line x1="41" y1={eyeY - 3} x2="36" y2={eyeY - 5} stroke="#78350f" strokeWidth="1.5" strokeLinecap="round" />
            {/* Headband / Bandage on cheek */}
            <rect x="19" y={eyeY + 3} width="5" height="4" rx="1" fill="#06b6d4" opacity="0.8" transform="rotate(-15 21 38)" />
            {/* Big determined smile */}
            <path d={`M26 ${mouthY} Q32 ${mouthY + 4} 38 ${mouthY}`} stroke="#78350f" strokeWidth="2" fill="none" strokeLinecap="round" />
          </g>
        );

      case 'welcome':
      case 'happy':
      default:
        return (
          <g>
            {/* Big shiny eyes */}
            <ellipse cx="26" cy={eyeY} rx="3" ry="4" fill="#18181b" />
            <circle cx="27" cy={eyeY - 1.5} r="1.2" fill="#ffffff" />
            <ellipse cx="38" cy={eyeY} rx="3" ry="4" fill="#18181b" />
            <circle cx="39" cy={eyeY - 1.5} r="1.2" fill="#ffffff" />
            {/* Rosy cheeks */}
            <circle cx="21" cy={eyeY + 3} r="2" fill="#ef4444" opacity="0.4" />
            <circle cx="43" cy={eyeY + 3} r="2" fill="#ef4444" opacity="0.4" />
            {/* Happy open mouth */}
            <path d={`M27 ${mouthY - 1} Q32 ${mouthY + 5} 37 ${mouthY - 1} Z`} fill="#ef4444" />
            <path d={`M27 ${mouthY - 1} Q32 ${mouthY + 5} 37 ${mouthY - 1}`} stroke="#78350f" strokeWidth="1.5" fill="none" />
          </g>
        );
    }
  };

  const stageNames = ['Brasita', 'Llamita', 'Fueguito', 'Fogata', 'Fénix'];
  const name = stageNames[s - 1];

  return (
    <div className={`inline-flex flex-col items-center justify-center shrink-0 ${className}`}>
      <svg
        width={size}
        height={size}
        viewBox="0 0 64 64"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
        className="overflow-visible"
      >
        <defs>
          <linearGradient id="mascotGrad" x1="32" y1="8" x2="32" y2="56" gradientUnits="userSpaceOnUse">
            <stop stopColor="#f59e0b" />
            <stop offset="0.6" stopColor="#ea580c" />
            <stop offset="1" stopColor="#dc2626" />
          </linearGradient>
          <linearGradient id="mascotInnerGrad" x1="32" y1="18" x2="32" y2="50" gradientUnits="userSpaceOnUse">
            <stop stopColor="#fef08a" />
            <stop offset="0.7" stopColor="#fbbf24" />
            <stop offset="1" stopColor="#f97316" />
          </linearGradient>
          <linearGradient id="phoenixGradL" x1="8" y1="16" x2="22" y2="42" gradientUnits="userSpaceOnUse">
            <stop stopColor="#fbbf24" />
            <stop offset="1" stopColor="#dc2626" />
          </linearGradient>
          <linearGradient id="phoenixGradR" x1="56" y1="16" x2="42" y2="42" gradientUnits="userSpaceOnUse">
            <stop stopColor="#fbbf24" />
            <stop offset="1" stopColor="#dc2626" />
          </linearGradient>
        </defs>

        {renderMascotBody()}
        {renderFace()}
      </svg>
      {showName && <span className="text-[10px] font-bold text-amber-300 mt-0.5">{name}</span>}
    </div>
  );
};
