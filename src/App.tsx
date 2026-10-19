import { useMemo, useState } from 'react';
import rutinaData from './data/rutina.json';
import { RutinaData, DiaEntrenamiento, Bloque } from './types/workout';
import { Header } from './components/Header';
import { HomeView } from './views/HomeView';
import { DayDetailView } from './views/DayDetailView';
import { ActiveWorkoutView } from './views/ActiveWorkoutView';
import { WorkoutCompleteModal } from './components/WorkoutCompleteModal';
import { useWakeLock } from './hooks/useWakeLock';
import { useAudioBeeps } from './hooks/useAudioBeeps';
import { useActivities } from './hooks/useActivities';
import { useBlockProgress } from './hooks/useBlockProgress';
import { useCurrentUser } from './auth/AuthContext';
import { todayKey, weekStart } from './gamification';
import { buildWorkoutDayActivity, isDayFinished, weekCompletedDays } from './utils/workoutDay';


type ViewMode = 'home' | 'day_detail' | 'active_workout';

export default function App() {
  const user = useCurrentUser();
  const rutina = { ...(rutinaData as RutinaData), usuario: user.displayName };
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
  const { activities, addActivity, syncStatus } = useActivities(user.userId);
  const { progress, recordBlock } = useBlockProgress(user.userId);

  // El estado "completado" se deriva de las actividades de la semana actual y de los bloques de hoy.
  const today = todayKey();
  const completedDays = useMemo(
    () => weekCompletedDays(activities, today, weekStart(today)),
    [activities, today],
  );
  const completedBlocks = useMemo(
    () => Object.fromEntries(Object.keys(progress).map((key) => [key, true])),
    [progress],
  );

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
      const updated = recordBlock(selectedDay.id, activeBlockIndex, activeBlock, totalSeconds, rounds);

      // El día termina cuando todos sus bloques están completados (en cualquier orden).
      // Se guarda una sola actividad por día de rutina y fecha, aunque se repita algún bloque.
      const alreadySaved = activities.some(
        (a) => a.type === 'workout_day' && a.dayId === selectedDay.id && a.occurredOn === todayKey(),
      );
      if (!alreadySaved && isDayFinished(selectedDay, updated)) {
        addActivity(buildWorkoutDayActivity(selectedDay, updated, todayKey()));
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
          userName={user.displayName}
          syncStatus={syncStatus}
          onSignOut={user.signOut}
        />
      )}

      {/* Main Container */}
      <main className={`flex-1 max-w-md w-full mx-auto ${currentView === 'active_workout' ? '' : 'px-4 py-3'}`}>
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
