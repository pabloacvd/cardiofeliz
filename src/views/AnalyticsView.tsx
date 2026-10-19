import React, { useMemo, useState } from 'react';
import {
  ArrowLeft,
  Flame,
  Snowflake,
  TrendingUp,
  Zap,
  Activity as ActivityIcon,
  Footprints,
  Clock,
  Sparkles,
  BarChart3,
} from 'lucide-react';
import type { Activity, VacationPeriod } from '../types/gamification';
import type { GameSummary } from '../gamification';
import {
  computeAnalyticsSummary,
  computeDailyMinutes,
  computeFeelingTrend,
  computeMonthlyHeatmap,
  computePaceHistory,
  computeTypeDistribution,
  computeWeeklyHistory,
} from '../gamification/analytics';
import { challengeHistory } from '../gamification/challenges';
import { Mascot } from '../components/Mascot';
import { HeatmapCalendar } from '../components/analytics/HeatmapCalendar';
import {
  MinutesBarChart,
  KmBarChart,
  CaloriesAreaChart,
  PaceLineChart,
  TypePieChart,
  FeelingLineChart,
} from '../components/analytics/ActivityCharts';
import { PersonalRecordsCard } from '../components/analytics/PersonalRecordsCard';
import { AchievementsGallery } from '../components/analytics/AchievementsGallery';
import { ChallengesHistory } from '../components/analytics/ChallengesHistory';
import { AccountSection } from '../components/analytics/AccountSection';

export type AnalyticsRange = 'week' | 'month' | 'all';

interface AnalyticsViewProps {
  activities: readonly Activity[];
  vacations: readonly VacationPeriod[];
  today: string;
  game: GameSummary;
  userName: string;
  weightKg: number | null;
  unlockedAtMap?: Record<string, string>;
  onBack: () => void;
  onEditWeight: () => void;
  onManageVacations: () => void;
  onSignOut: () => void;
}

export const AnalyticsView: React.FC<AnalyticsViewProps> = ({
  activities,
  vacations,
  today,
  game,
  userName,
  weightKg,
  unlockedAtMap = {},
  onBack,
  onEditWeight,
  onManageVacations,
  onSignOut,
}) => {
  const [range, setRange] = useState<AnalyticsRange>('week');

  const context = useMemo(
    () => ({
      activities,
      vacations,
      today,
      weightKg,
      displayName: userName,
    }),
    [activities, vacations, today, weightKg, userName],
  );

  const summary = useMemo(() => computeAnalyticsSummary(context), [context]);
  const daily7 = useMemo(() => computeDailyMinutes(context, 7), [context]);
  const daily30 = useMemo(() => computeDailyMinutes(context, 30), [context]);
  const weeklyHistory = useMemo(() => computeWeeklyHistory(context, 8), [context]);
  const paceHistory = useMemo(() => computePaceHistory(context), [context]);
  const typeDistribution = useMemo(() => computeTypeDistribution(context), [context]);
  const feelingTrend = useMemo(() => computeFeelingTrend(context), [context]);
  const heatmap = useMemo(() => computeMonthlyHeatmap(context, today), [context, today]);
  const challenges = useMemo(() => challengeHistory(context), [context]);

  const hasActivities = activities.length > 0;

  // Month name formatting for heatmap
  const monthName = useMemo(() => {
    const [y, m] = today.split('-').map(Number);
    const d = new Date(y, m - 1, 1);
    return d.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
  }, [today]);

  return (
    <div className="space-y-5 animate-fadeIn pb-12">
      {/* Top Header Navigation */}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={onBack}
          aria-label="Volver a la rutina"
          className="flex items-center gap-2 px-3 py-2 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-200 text-xs font-bold active:bg-surface-700 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Volver</span>
        </button>

        <h2 className="text-base font-extrabold text-white flex items-center gap-1.5">
          <BarChart3 className="w-4 h-4 text-cardio-primary" />
          Analíticas y Progreso
        </h2>

        {/* Range Selector */}
        <div className="flex p-0.5 rounded-xl bg-surface-800 border border-zinc-700 text-[11px] font-semibold">
          <button
            type="button"
            onClick={() => setRange('week')}
            className={`px-2.5 py-1 rounded-lg transition-colors ${
              range === 'week' ? 'bg-cardio-primary text-black font-extrabold' : 'text-zinc-400'
            }`}
          >
            Semana
          </button>
          <button
            type="button"
            onClick={() => setRange('month')}
            className={`px-2.5 py-1 rounded-lg transition-colors ${
              range === 'month' ? 'bg-cardio-primary text-black font-extrabold' : 'text-zinc-400'
            }`}
          >
            Mes
          </button>
          <button
            type="button"
            onClick={() => setRange('all')}
            className={`px-2.5 py-1 rounded-lg transition-colors ${
              range === 'all' ? 'bg-cardio-primary text-black font-extrabold' : 'text-zinc-400'
            }`}
          >
            Todo
          </button>
        </div>
      </div>

      {/* Mascot & Level Hero */}
      <div className="rounded-2xl border border-zinc-800 bg-gradient-to-br from-surface-900 via-surface-900 to-black p-4 shadow-xl flex items-center gap-4">
        <div className="p-2 rounded-2xl bg-black/60 border border-zinc-800 shrink-0">
          <Mascot stage={game.mascot.stage} mood={game.coach.mood} size={52} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-xs font-extrabold text-white">
              Nivel {game.level.level}: <span className="text-cardio-primary">{game.level.tierName}</span>
            </span>
          </div>
          <p className="text-[11px] font-bold text-amber-300 mt-0.5">
            {game.mascot.name} · &ldquo;{game.mascot.catchphrase}&rdquo;
          </p>
          <div className="mt-2">
            <div className="flex justify-between text-[10px] text-zinc-400 font-semibold mb-1">
              <span>{game.level.xpIntoLevel} XP</span>
              <span>{game.level.xpForNextLevel} XP</span>
            </div>
            <div className="h-2 rounded-full bg-surface-700 overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-cardio-primary to-cyan-400 transition-all"
                style={{ width: `${Math.round(game.level.progress * 100)}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Quick Stats Grid */}
      <div className="grid grid-cols-3 gap-2">
        <div className="p-3 rounded-xl bg-surface-900 border border-zinc-800 text-center">
          <div className="flex items-center justify-center gap-1 text-[10px] font-bold text-zinc-500 uppercase mb-1">
            <Flame className="w-3.5 h-3.5 text-orange-400" />
            <span>Racha</span>
          </div>
          <span className="text-base font-black text-white">{summary.currentStreak} d</span>
          <span className="text-[10px] text-zinc-500 block">Mejor: {summary.bestStreak} d</span>
        </div>

        <div className="p-3 rounded-xl bg-surface-900 border border-zinc-800 text-center">
          <div className="flex items-center justify-center gap-1 text-[10px] font-bold text-zinc-500 uppercase mb-1">
            <Snowflake className="w-3.5 h-3.5 text-cyan-400" />
            <span>Hielos</span>
          </div>
          <span className="text-base font-black text-white">{game.streak.freezes}</span>
          <span className="text-[10px] text-zinc-500 block">Disponibles</span>
        </div>

        <div className="p-3 rounded-xl bg-surface-900 border border-zinc-800 text-center">
          <div className="flex items-center justify-center gap-1 text-[10px] font-bold text-zinc-500 uppercase mb-1">
            <Sparkles className="w-3.5 h-3.5 text-amber-400" />
            <span>Semanas</span>
          </div>
          <span className="text-base font-black text-white">{summary.currentWeeklyStreak}</span>
          <span className="text-[10px] text-zinc-500 block">Perfectas</span>
        </div>
      </div>

      {/* Totales Globales */}
      <div className="grid grid-cols-3 gap-2">
        <div className="p-3 rounded-xl bg-black/40 border border-zinc-800/80 text-center">
          <span className="text-[10px] text-zinc-500 uppercase font-semibold block">Minutos</span>
          <span className="text-sm font-extrabold text-emerald-400 font-timer">{summary.totalMinutes} min</span>
        </div>
        <div className="p-3 rounded-xl bg-black/40 border border-zinc-800/80 text-center">
          <span className="text-[10px] text-zinc-500 uppercase font-semibold block">Distancia</span>
          <span className="text-sm font-extrabold text-cyan-400 font-timer">{summary.totalKm} km</span>
        </div>
        <div className="p-3 rounded-xl bg-black/40 border border-zinc-800/80 text-center">
          <span className="text-[10px] text-zinc-500 uppercase font-semibold block">Calorías</span>
          <span className="text-sm font-extrabold text-amber-400 font-timer">
            {summary.totalCalories > 0 ? `~${summary.totalCalories}` : '—'}
          </span>
        </div>
      </div>

      {/* Comparación Semanal */}
      <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-emerald-500/20 text-emerald-400">
              <ActivityIcon className="w-4 h-4" />
            </div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Meta Semanal: Esta semana vs Anterior
            </h3>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3 text-center">
          <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80">
            <span className="text-[11px] text-zinc-400 font-bold block mb-1">Esta Semana</span>
            <div className="flex justify-around items-center">
              <div>
                <span className="text-xs text-zinc-500 block">Entrenos</span>
                <span className="text-sm font-extrabold text-emerald-400">
                  {summary.thisWeek.workouts}/{summary.thisWeek.workoutsGoal}
                </span>
              </div>
              <div>
                <span className="text-xs text-zinc-500 block">Corridas</span>
                <span className="text-sm font-extrabold text-cyan-400">
                  {summary.thisWeek.runs}/{summary.thisWeek.runsGoal}
                </span>
              </div>
            </div>
          </div>

          <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80">
            <span className="text-[11px] text-zinc-400 font-bold block mb-1">Semana Anterior</span>
            <div className="flex justify-around items-center">
              <div>
                <span className="text-xs text-zinc-500 block">Entrenos</span>
                <span className="text-sm font-extrabold text-zinc-300">
                  {summary.prevWeek.workouts}/{summary.prevWeek.workoutsGoal}
                </span>
              </div>
              <div>
                <span className="text-xs text-zinc-500 block">Corridas</span>
                <span className="text-sm font-extrabold text-zinc-300">
                  {summary.prevWeek.runs}/{summary.prevWeek.runsGoal}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Minutos Activos Chart */}
      <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-emerald-500/20 text-emerald-400">
              <Clock className="w-4 h-4" />
            </div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Minutos Activos {range === 'week' ? '(Últimos 7 días)' : range === 'month' ? '(Últimos 30 días)' : '(Últimas semanas)'}
            </h3>
          </div>
        </div>

        {hasActivities ? (
          <MinutesBarChart
            data={range === 'week' ? daily7 : range === 'month' ? daily30 : weeklyHistory}
          />
        ) : (
          <p className="text-xs text-zinc-500 text-center py-6">Registrá tu primera actividad para ver este gráfico.</p>
        )}
      </div>

      {/* Km Corridos & Ritmo */}
      <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-cyan-500/20 text-cyan-400">
              <Footprints className="w-4 h-4" />
            </div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Km Corridos por Semana
            </h3>
          </div>
        </div>

        {summary.totalRuns > 0 ? (
          <KmBarChart data={weeklyHistory} />
        ) : (
          <p className="text-xs text-zinc-500 text-center py-6">Usá &ldquo;Hoy corrí&rdquo; para ver tus km en el tiempo.</p>
        )}
      </div>

      {/* Ritmo min/km (si hay corridas con distancia) */}
      {paceHistory.length > 0 && (
        <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-blue-500/20 text-blue-400">
              <TrendingUp className="w-4 h-4" />
            </div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Evolución del Ritmo (min/km)
            </h3>
          </div>
          <PaceLineChart data={paceHistory} />
        </div>
      )}

      {/* Calorías Estimadas Chart */}
      <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
            <Zap className="w-4 h-4" />
          </div>
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
            Calorías Estimadas (Semanales)
          </h3>
        </div>

        {summary.totalCalories > 0 ? (
          <CaloriesAreaChart data={weeklyHistory} />
        ) : (
          <div className="text-center py-6 space-y-2">
            <p className="text-xs text-zinc-500">Cargá tu peso corporal para calcular y visualizar las calorías quemadas.</p>
            <button
              type="button"
              onClick={onEditWeight}
              className="px-3 py-1.5 rounded-xl bg-surface-800 border border-zinc-700 text-xs font-bold text-zinc-200"
            >
              Cargar peso
            </button>
          </div>
        )}
      </div>

      {/* Calendario de Constancia (Heatmap) */}
      <HeatmapCalendar days={heatmap} monthName={monthName} />

      {/* Distribución por Tipo de Actividad (Dona) */}
      {typeDistribution.length > 0 && (
        <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-purple-500/20 text-purple-400">
              <ActivityIcon className="w-4 h-4" />
            </div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Distribución de Actividades
            </h3>
          </div>
          <TypePieChart data={typeDistribution} />
        </div>
      )}

      {/* Tendencia de Sensación (si hay registros) */}
      {feelingTrend.length > 0 && (
        <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-pink-500/20 text-pink-400">
              <Sparkles className="w-4 h-4" />
            </div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Sensación en el Tiempo (1 = Pesado, 5 = Excelente)
            </h3>
          </div>
          <FeelingLineChart data={feelingTrend} />
        </div>
      )}

      {/* Récords Personales */}
      <PersonalRecordsCard records={summary.records} />

      {/* Galería de Logros */}
      <AchievementsGallery achievements={game.achievements} unlockedAtMap={unlockedAtMap} />

      {/* Desafíos Semanales */}
      <ChallengesHistory currentChallenge={game.challenge} history={challenges} />

      {/* Cuenta & Ajustes */}
      <AccountSection
        userName={userName}
        weightKg={weightKg}
        onEditWeight={onEditWeight}
        onManageVacations={onManageVacations}
        isVacationActive={game.vacation.active}
        onSignOut={onSignOut}
      />
    </div>
  );
};

export default AnalyticsView;
