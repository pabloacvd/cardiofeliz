import { useState } from 'react';
import rutinaData from './data/rutina.json';
import { RutinaData, DiaEntrenamiento, Bloque } from './types/workout';
import { Header } from './components/Header';
import { HomeView } from './views/HomeView';
import { DayDetailView } from './views/DayDetailView';
import { ActiveWorkoutView } from './views/ActiveWorkoutView';
import { WorkoutCompleteModal } from './components/WorkoutCompleteModal';
import { useWakeLock } from './hooks/useWakeLock';
import { useAudioBeeps } from './hooks/useAudioBeeps';
import { useWorkoutStorage } from './hooks/useWorkoutStorage';

type ViewMode = 'home' | 'day_detail' | 'active_workout';

export default function App() {
  const rutina = rutinaData as RutinaData;
  const [currentView, setCurrentView] = useState<ViewMode>('home');
  const [selectedDay, setSelectedDay] = useState<DiaEntrenamiento | null>(null);
  const [activeBlock, setActiveBlock] = useState<Bloque | null>(null);
  const [activeBlockIndex, setActiveBlockIndex] = useState<number | null>(null);

  const [completedModal, setCompletedModal] = useState<{
    bloque: Bloque;
    totalSeconds: number;
    rounds?: number;
  } | null>(null);

  const { isLocked } = useWakeLock();
  const { isMuted, toggleMute, unlockAudio } = useAudioBeeps();
  const { completedBlocks, completedDays, markBlockComplete, markDayComplete } =
    useWorkoutStorage();

  // Navigation handlers
  const handleSelectDay = (dia: DiaEntrenamiento) => {
    unlockAudio();
    setSelectedDay(dia);
    setCurrentView('day_detail');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleStartBlock = (bloque: Bloque, blockIndex: number) => {
    unlockAudio();
    setActiveBlock(bloque);
    setActiveBlockIndex(blockIndex);
    setCurrentView('active_workout');
  };

  const handleExitActiveWorkout = () => {
    setActiveBlock(null);
    setActiveBlockIndex(null);
    setCurrentView('day_detail');
  };

  const handleBlockCompleted = (totalSeconds: number, rounds?: number) => {
    if (selectedDay && activeBlock && activeBlockIndex !== null) {
      markBlockComplete(selectedDay.id, activeBlockIndex, activeBlock.nombre, totalSeconds, rounds);

      // Check if this was the last block of the day
      if (activeBlockIndex === selectedDay.bloques.length - 1) {
        markDayComplete(selectedDay.id);
      }

      setCompletedModal({
        bloque: activeBlock,
        totalSeconds,
        rounds,
      });
    }
  };

  const handleNextBlock = () => {
    if (selectedDay && activeBlockIndex !== null) {
      const nextIndex = activeBlockIndex + 1;
      if (nextIndex < selectedDay.bloques.length) {
        const nextBlock = selectedDay.bloques[nextIndex];
        setCompletedModal(null);
        setActiveBlock(nextBlock);
        setActiveBlockIndex(nextIndex);
        setCurrentView('active_workout');
        return;
      }
    }
    setCompletedModal(null);
    setCurrentView('day_detail');
  };

  const handleBackToDayFromModal = () => {
    setCompletedModal(null);
    setActiveBlock(null);
    setActiveBlockIndex(null);
    setCurrentView('day_detail');
  };

  const handleGoHome = () => {
    setSelectedDay(null);
    setActiveBlock(null);
    setActiveBlockIndex(null);
    setCurrentView('home');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const hasNextBlock =
    Boolean(selectedDay &&
    activeBlockIndex !== null &&
    activeBlockIndex < selectedDay.bloques.length - 1);

  return (
    <div className="min-h-screen bg-black text-white flex flex-col font-sans selection:bg-cardio-primary selection:text-black">
      {/* Header is shown on Home and DayDetail views */}
      {currentView !== 'active_workout' && (
        <Header
          isMuted={isMuted}
          onToggleMute={toggleMute}
          isWakeLocked={isLocked}
          onHomeClick={handleGoHome}
        />
      )}

      {/* Main Container */}
      <main className="flex-1 max-w-md w-full mx-auto px-4 py-3">
        {currentView === 'home' && (
          <HomeView
            rutina={rutina}
            onSelectDay={handleSelectDay}
            completedDays={completedDays}
          />
        )}

        {currentView === 'day_detail' && selectedDay && (
          <DayDetailView
            dia={selectedDay}
            onBack={handleGoHome}
            onStartBlock={handleStartBlock}
            completedBlocks={completedBlocks}
          />
        )}

        {currentView === 'active_workout' && activeBlock && selectedDay && (
          <ActiveWorkoutView
            bloque={activeBlock}
            diaNombre={selectedDay.nombre}
            onExit={handleExitActiveWorkout}
            onBlockCompleted={handleBlockCompleted}
          />
        )}
      </main>

      {/* Completion Modal */}
      {completedModal && (
        <WorkoutCompleteModal
          bloque={completedModal.bloque}
          totalSeconds={completedModal.totalSeconds}
          rounds={completedModal.rounds}
          hasNextBlock={hasNextBlock}
          onNextBlock={handleNextBlock}
          onBackToDay={handleBackToDayFromModal}
        />
      )}
    </div>
  );
}
