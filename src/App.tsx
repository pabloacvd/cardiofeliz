import React, { useMemo, useState, Suspense, useEffect } from 'react';
import { DiaEntrenamiento, Bloque } from './types/workout';
import { Header } from './components/Header';
import { HomeView } from './views/HomeView';
import { DayDetailView } from './views/DayDetailView';
import { WarmupView } from './views/WarmupView';
import { BlockDetailView } from './views/BlockDetailView';
import { ActiveWorkoutView } from './views/ActiveWorkoutView';
import { RoutineEditorView } from './views/RoutineEditorView';
import { WorkoutCompleteModal } from './components/WorkoutCompleteModal';
import { useWakeLock } from './hooks/useWakeLock';
import { useAudioBeeps } from './hooks/useAudioBeeps';
import { useActivities } from './hooks/useActivities';
import { useProfileWeight } from './hooks/useProfileWeight';
import { useAchievements } from './hooks/useAchievements';
import { useVacations } from './hooks/useVacations';
import { useCoachDismissal } from './hooks/useCoachDismissal';
import { useToasts } from './hooks/useToasts';
import { useToday } from './hooks/useToday';
import { ToastStack } from './components/ToastStack';
import { VacationSheet } from './components/VacationSheet';
import { WeightSheet } from './components/WeightSheet';
import { useBlockProgress } from './hooks/useBlockProgress';
import { useRoutine } from './hooks/useRoutine';
import { useCurrentUser } from './auth/AuthContext';
import { computeGameSummary, logOutcome, todayKey, weekStart, withActivity, type LogOutcome } from './gamification';
import { blockKey, buildWorkoutDayActivity, isDayFinished, weekCompletedDays } from './utils/workoutDay';
import { buildToasts, withClaimedAchievements } from './utils/celebrations';

const AnalyticsView = React.lazy(() => import('./views/AnalyticsView'));

type ViewMode = 'home' | 'day_detail' | 'warmup' | 'block_detail' | 'active_workout' | 'analytics' | 'settings';

export default function App() {
  const user = useCurrentUser();
  const { rutina, isCustom, saveRoutine, resetRoutine, syncStatus: routineSyncStatus } = useRoutine(
    user.userId,
    user.displayName,
  );
  const [currentView, setCurrentView] = useState<ViewMode>('home');
  // El día se guarda por id y se deriva de la rutina vigente: un cambio de rutina no deja una copia vieja.
  const [selectedDayId, setSelectedDayId] = useState<string | null>(null);
  const selectedDay = useMemo<DiaEntrenamiento | null>(
    () => rutina.dias_entrenamiento.find((d) => d.id === selectedDayId) ?? null,
    [rutina, selectedDayId],
  );
  const [activeBlock, setActiveBlock] = useState<Bloque | null>(null);
  // Posición del bloque activo en el orden actual de la rutina (-1 si ya no existe en el día).
  const activeBlockIndex =
    selectedDay && activeBlock ? selectedDay.bloques.findIndex((b) => b.id === activeBlock.id) : -1;

  const [completedModal, setCompletedModal] = useState<{
    bloque: Bloque;
    totalSeconds: number;
    rounds?: number;
    dayResult?: LogOutcome | null;
  } | null>(null);

  const { isLocked, requestWakeLock, releaseWakeLock } = useWakeLock();
  const { isMuted, toggleMute, unlockAudio, playVictory } = useAudioBeeps();
  const { activities, addActivity, updateActivity, removeActivity, fillMissingCalories, syncStatus } =
    useActivities(user.userId);
  const profileWeight = useProfileWeight(user.userId);
  const { vacations, startVacation, endActiveVacation, deleteVacation } = useVacations(user.userId);
  const [isVacationSheetOpen, setIsVacationSheetOpen] = useState(false);
  const [isWeightSheetOpen, setIsWeightSheetOpen] = useState(false);
  const { progress, recordBlock } = useBlockProgress(user.userId, rutina);
  const achievements = useAchievements(user.userId);
  const { toasts, push: pushToasts, dismiss: dismissToast } = useToasts();

  // El estado "completado" se deriva de las actividades de la semana actual y de los bloques de hoy.
  const today = useToday();
  const coachDismissal = useCoachDismissal(user.userId, today);
  const game = useMemo(
    () => computeGameSummary({ activities, vacations, today, displayName: user.displayName }),
    [activities, vacations, today, user.displayName],
  );

  // Tras un registro rápido: se registran los logros (una sola vez) y se avisa con toasts.
  // Al corregir una corrida no se vuelve a celebrar nivel ni congelador.
  const handleQuickLogOutcome = (outcome: LogOutcome, isAdjustment: boolean) => {
    const claimed = achievements.claimNew(outcome.newAchievements.map((a) => a.id));
    const toCelebrate = withClaimedAchievements(
      isAdjustment ? { ...outcome, leveledUp: false, earnedFreeze: false } : outcome,
      claimed,
    );
    pushToasts(buildToasts(toCelebrate));
  };
  const completedDays = useMemo(
    () => weekCompletedDays(activities, today, weekStart(today)),
    [activities, today],
  );
  const completedBlocks = useMemo(
    () => Object.fromEntries(Object.keys(progress).map((key) => [key, true])),
    [progress],
  );

  // Global Wake Lock: activate whenever the user is training or in a workout view.
  useEffect(() => {
    const workoutViews: ViewMode[] = ['day_detail', 'warmup', 'block_detail', 'active_workout'];
    if (workoutViews.includes(currentView)) {
      requestWakeLock();
    } else {
      releaseWakeLock();
    }
  }, [currentView, activeBlock, requestWakeLock, releaseWakeLock]);

  // Navigation handlers
  const handleSelectDay = (dia: DiaEntrenamiento) => {
    unlockAudio();
    setSelectedDayId(dia.id);
    setCurrentView('day_detail');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  /** Abre la pantalla de calentamiento antes del primer bloque. */
  const handleStartWarmup = () => {
    unlockAudio();
    setCurrentView('warmup');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  /** Muestra el detalle de un bloque antes de iniciar el timer. */
  const handleShowBlockDetail = (bloque: Bloque) => {
    unlockAudio();
    setActiveBlock(bloque);
    setCurrentView('block_detail');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  /** Inicia el timer del bloque activo (desde BlockDetailView). */
  const handleStartBlock = (bloque: Bloque) => {
    unlockAudio();
    setActiveBlock(bloque);
    setCurrentView('active_workout');
  };

  const handleExitActiveWorkout = () => {
    setActiveBlock(null);
    setCurrentView('day_detail');
  };

  const handleBlockCompleted = (totalSeconds: number, rounds?: number) => {
    if (selectedDay && activeBlock) {
      const updated = recordBlock(selectedDay.id, activeBlock, totalSeconds, rounds);

      // El día termina cuando todos sus bloques están completados (en cualquier orden).
      // Se guarda una sola actividad por día de rutina y fecha, aunque se repita algún bloque.
      const alreadySaved = activities.some(
        (a) => a.type === 'workout_day' && a.dayId === selectedDay.id && a.occurredOn === todayKey(),
      );
      let dayResult: LogOutcome | null = null;
      if (!alreadySaved && isDayFinished(selectedDay, updated)) {
        const before = { activities, vacations, today: todayKey(), displayName: user.displayName };
        const saved = addActivity(buildWorkoutDayActivity(selectedDay, updated, todayKey()), {
          weightKg: profileWeight.weightKg,
          vacations,
        });
        const outcome = logOutcome(before, withActivity(before, saved));
        const claimed = achievements.claimNew(outcome.newAchievements.map((a) => a.id));
        dayResult = withClaimedAchievements(outcome, claimed);
      }

      setCompletedModal({
        bloque: activeBlock,
        totalSeconds,
        rounds,
        dayResult,
      });
    }
  };

  const handleNextBlock = () => {
    if (selectedDay && activeBlockIndex >= 0) {
      const nextBlock = selectedDay.bloques[activeBlockIndex + 1];
      if (nextBlock) {
        setCompletedModal(null);
        setActiveBlock(nextBlock);
        setCurrentView('block_detail');
        window.scrollTo({ top: 0, behavior: 'smooth' });
        return;
      }
    }
    setCompletedModal(null);
    setCurrentView('day_detail');
  };

  const handleBackToDayFromModal = () => {
    setCompletedModal(null);
    setActiveBlock(null);
    setCurrentView('day_detail');
  };

  const handleGoHome = () => {
    setSelectedDayId(null);
    setActiveBlock(null);
    setCurrentView('home');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const hasNextBlock = Boolean(
    selectedDay && activeBlockIndex >= 0 && activeBlockIndex < selectedDay.bloques.length - 1,
  );

  const handleOpenAnalytics = () => {
    setSelectedDayId(null);
    setActiveBlock(null);
    setCurrentView('analytics');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleOpenSettings = () => {
    setSelectedDayId(null);
    setActiveBlock(null);
    setCurrentView('settings');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleSaveWeightFromAnalytics = (kg: number) => {
    if (profileWeight.setWeightKg(kg)) {
      fillMissingCalories(kg);
      setIsWeightSheetOpen(false);
    }
  };

  return (
    <div className="min-h-screen bg-black text-white flex flex-col font-sans selection:bg-cardio-primary selection:text-black">
      {/* Header is shown on Home, DayDetail, and Analytics views */}
      {currentView !== 'active_workout' && (
        <Header
          isMuted={isMuted}
          onToggleMute={toggleMute}
          isWakeLocked={isLocked}
          onHomeClick={handleGoHome}
          onAnalyticsClick={handleOpenAnalytics}
          isAnalyticsActive={currentView === 'analytics'}
          userName={user.displayName}
          syncStatus={syncStatus}
          onSignOut={user.signOut}
        />
      )}

      {/* Main Container */}
      <main className={`flex-1 max-w-md w-full mx-auto ${currentView === 'active_workout' || currentView === 'warmup' || currentView === 'block_detail' ? '' : 'px-4 py-3'}`}>
        {currentView === 'home' && (
          <HomeView
            rutina={rutina}
            onSelectDay={handleSelectDay}
            completedDays={completedDays}
            game={game}
            showCoach={!coachDismissal.dismissed}
            onDismissCoach={coachDismissal.dismiss}
            onOpenVacations={() => setIsVacationSheetOpen(true)}
            onOpenRoutineSettings={handleOpenSettings}
            quickLog={{
              today,
              activities,
              vacations,
              weightKg: profileWeight.weightKg,
              weightLoaded: profileWeight.isLoaded,
              weightPromptDismissed: profileWeight.promptDismissed,
              onDismissWeightPrompt: profileWeight.dismissPrompt,
              onSetWeight: profileWeight.setWeightKg,
              addActivity,
              updateActivity,
              removeActivity,
              fillMissingCalories,
              onUnlockAudio: unlockAudio,
              onCelebrate: playVictory,
              onOutcome: handleQuickLogOutcome,
            }}
          />
        )}

        {currentView === 'day_detail' && selectedDay && (
          <DayDetailView
            dia={selectedDay}
            onBack={handleGoHome}
            onStartWarmup={handleStartWarmup}
            onShowBlockDetail={handleShowBlockDetail}
            completedBlocks={completedBlocks}
          />
        )}

        {currentView === 'warmup' && selectedDay && (
          <WarmupView
            dia={selectedDay}
            onBack={() => setCurrentView('day_detail')}
            onStartFirstBlock={() => {
              const firstBlock = selectedDay.bloques[0];
              if (firstBlock) handleShowBlockDetail(firstBlock);
            }}
          />
        )}

        {currentView === 'block_detail' && activeBlock && selectedDay && (
          <BlockDetailView
            bloque={activeBlock}
            diaNombre={selectedDay.nombre}
            onBack={() => setCurrentView('day_detail')}
            onStart={() => handleStartBlock(activeBlock)}
            isCompleted={activeBlock.id !== undefined && !!completedBlocks[blockKey(selectedDay.id, activeBlock.id!)]}
            isWakeLocked={isLocked}
          />
        )}

        {currentView === 'active_workout' && activeBlock && selectedDay && (
          <ActiveWorkoutView
            key={activeBlock.id}
            bloque={activeBlock}
            diaNombre={selectedDay.nombre}
            onExit={handleExitActiveWorkout}
            onBlockCompleted={handleBlockCompleted}
            isWakeLocked={isLocked}
          />
        )}

        {currentView === 'settings' && (
          <RoutineEditorView
            rutina={rutina}
            onSave={saveRoutine}
            onReset={resetRoutine}
            isCustom={isCustom}
            onBack={handleGoHome}
            syncStatus={routineSyncStatus}
            hasActiveBlockProgressToday={Object.keys(progress).length > 0}
          />
        )}

        {currentView === 'analytics' && (
          <Suspense
            fallback={
              <div className="py-20 text-center space-y-3">
                <div className="w-8 h-8 border-2 border-cardio-primary border-t-transparent rounded-full animate-spin mx-auto" />
                <p className="text-xs text-zinc-400 font-semibold">Cargando analíticas...</p>
              </div>
            }
          >
            <AnalyticsView
              activities={activities}
              vacations={vacations}
              today={today}
              game={game}
              userName={user.displayName}
              weightKg={profileWeight.weightKg}
              unlockedAtMap={achievements.unlockedAt}
              onBack={handleGoHome}
              onEditWeight={() => setIsWeightSheetOpen(true)}
              onManageVacations={() => setIsVacationSheetOpen(true)}
              onSignOut={user.signOut}
            />
          </Suspense>
        )}
      </main>

      <ToastStack toasts={toasts} onDismiss={dismissToast} />

      {isVacationSheetOpen && (
        <VacationSheet
          status={game.vacation}
          today={today}
          onClose={() => setIsVacationSheetOpen(false)}
          onStartVacation={startVacation}
          onEndVacation={endActiveVacation}
          onDeleteVacation={deleteVacation}
        />
      )}

      {isWeightSheetOpen && (
        <WeightSheet
          initialKg={profileWeight.weightKg}
          onSave={handleSaveWeightFromAnalytics}
          onClose={() => setIsWeightSheetOpen(false)}
        />
      )}

      {/* Completion Modal */}
      {completedModal && (
        <WorkoutCompleteModal
          bloque={completedModal.bloque}
          totalSeconds={completedModal.totalSeconds}
          rounds={completedModal.rounds}
          dayResult={completedModal.dayResult}
          mascotStage={game.mascot.stage}
          hasNextBlock={hasNextBlock}
          onNextBlock={handleNextBlock}
          onBackToDay={handleBackToDayFromModal}
        />
      )}
    </div>
  );
}
