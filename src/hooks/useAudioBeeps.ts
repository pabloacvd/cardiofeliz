import { useState, useCallback, useEffect } from 'react';
import { soundEngine } from '../utils/audio';

export function useAudioBeeps() {
  const [isMuted, setIsMuted] = useState(() => {
    try {
      return localStorage.getItem('cardiofeliz_muted') === 'true';
    } catch {
      return false;
    }
  });

  useEffect(() => {
    soundEngine.setMuted(isMuted);
    try {
      localStorage.setItem('cardiofeliz_muted', String(isMuted));
    } catch {
      // storage unavailable
    }
  }, [isMuted]);

  const toggleMute = useCallback(() => {
    setIsMuted((prev) => !prev);
  }, []);

  const unlockAudio = useCallback(() => {
    soundEngine.unlockAudio();
  }, []);

  const playCountdown = useCallback(() => {
    soundEngine.playCountdownTick();
  }, []);

  const playGo = useCallback(() => {
    soundEngine.playGoChime();
  }, []);

  const playRest = useCallback(() => {
    soundEngine.playRestChime();
  }, []);

  const playVictory = useCallback(() => {
    soundEngine.playVictoryFanfare();
  }, []);

  return {
    isMuted,
    toggleMute,
    unlockAudio,
    playCountdown,
    playGo,
    playRest,
    playVictory,
  };
}
