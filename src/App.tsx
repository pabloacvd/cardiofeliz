import React, { useMemo, useState, Suspense } from 'react';
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
import { useCurrentUser } from './auth/AuthContext';
import { computeGameSummary, logOutcome, todayKey, weekStart, withActivity, type LogOutcome } from './gamification';
import { buildWorkoutDayActivity, isDayFinished, weekCompletedDays } from './utils/workoutDay';
import { buildToasts, withClaimedAchievements } from './utils/celebrations';

const AnalyticsView = React.lazy(() => import('./views/AnalyticsView'));

type ViewMode = 'home' | 'day_detail' | 'active_workout' | 'analytics';

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
    dayResult?: LogOutcome | null;
  } | null>(null);

  const { isLocked } = useWakeLock();
  const { isMuted, toggleMute, unlockAudio, playVictory } = useAudioBeeps();
  const { activities, addActivity, updateActivity, removeActivity, fillMissingCalories, syncStatus } =
    useActivities(user.userId);
  const profileWeight = useProfileWeight(user.userId);
  const { vacations, startVacation, endActiveVacation, deleteVacation } = useVacations(user.userId);
  const [isVacationSheetOpen, setIsVacationSheetOpen] = useState(false);
  const [isWeightSheetOpen, setIsWeightSheetOpen] = useState(false);
  const { progress, recordBlock } = useBlockProgress(user.userId);
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

  const handleOpenAnalytics = () => {
    setSelectedDay(null);
    setActiveBlock(null);
    setActiveBlockIndex(null);
    setCurrentView('analytics');
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
      <main className={`flex-1 max-w-md w-full mx-auto ${currentView === 'active_workout' ? '' : 'px-4 py-3'}`}>
        {currentView === 'home' && (
          <HomeView
            rutina={rutina}
            onSelectDay={handleSelectDay}
            completedDays={completedDays}
            game={game}
            showCoach={!coachDismissal.dismissed}
            onDismissCoach={coachDismissal.dismiss}
            onOpenVacations={() => setIsVacationSheetOpen(true)}
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
