import { addDays, eachDay, weekEnd, weekStart, type DateKey } from './dates';
import { isRun, isWorkout, safeNumber, type GameContext } from './activities';
import { computeStreak } from './streak';
import { computeWeeklyStreak, weekProgress, type WeekProgress } from './weeks';
import { levelFromXp, type LevelInfo } from './levels';
import { computeXp } from './xp';
import { isOnVacation } from './vacations';

export interface DailyMinutesPoint {
  date: DateKey;
  label: string; // 'Lun 12', etc.
  workoutsMin: number;
  runsMin: number;
  restMin: number;
  totalMin: number;
  isVacation: boolean;
}

export interface WeeklyDataPoint {
  weekStart: DateKey;
  weekEnd: DateKey;
  label: string; // '12/03'
  workouts: number;
  runs: number;
  workoutsMin: number;
  runsMin: number;
  restMin: number;
  totalMin: number;
  km: number;
  calories: number;
  met: boolean;
  paused: boolean;
}

export interface PacePoint {
  id: string;
  date: DateKey;
  label: string;
  distanceKm: number;
  durationMinutes: number;
  paceMinKm: number; // decimal minutes per km (e.g. 5.5 = 5:30)
  paceFormatted: string; // '5:30 min/km'
  location: string;
  feeling: number | null;
}

export interface TypeDistributionPoint {
  name: string;
  value: number; // count
  minutes: number;
  color: string;
}

export interface FeelingPoint {
  date: DateKey;
  label: string;
  feeling: number;
  type: string;
}

export interface PersonalRecords {
  bestStreakDays: number;
  longestRunMinutes: number;
  longestRunKm: number;
  bestPaceMinKm: number | null;
  bestPaceFormatted: string | null;
  maxRoundsAmrap: number;
  mostActiveWeekMinutes: number;
  mostActiveWeekLabel: string | null;
}

export interface HeatmapDay {
  date: DateKey;
  dayOfMonth: number;
  dayOfWeek: number; // 0 = Mon, 6 = Sun
  isCurrentMonth: boolean;
  isToday: boolean;
  isFuture: boolean;
  isVacation: boolean;
  minutes: number;
  activitiesCount: number;
  intensity: 0 | 1 | 2 | 3 | 4; // 0 = 0min, 1 = 1-15min, 2 = 16-30min, 3 = 31-45min, 4 = >45min
}

export interface AnalyticsSummary {
  totalXp: number;
  level: LevelInfo;
  currentStreak: number;
  bestStreak: number;
  currentWeeklyStreak: number;
  bestWeeklyStreak: number;
  totalActivities: number;
  totalWorkouts: number;
  totalRuns: number;
  totalActiveRest: number;
  totalMinutes: number;
  totalKm: number;
  totalCalories: number;
  thisWeek: WeekProgress;
  prevWeek: WeekProgress;
  records: PersonalRecords;
}

const DAY_NAMES = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

function formatPace(minPerKm: number): string {
  const min = Math.floor(minPerKm);
  const sec = Math.round((minPerKm - min) * 60);
  const formattedSec = sec === 60 ? '00' : sec.toString().padStart(2, '0');
  const formattedMin = sec === 60 ? min + 1 : min;
  return `${formattedMin}:${formattedSec} /km`;
}

/** Agrupación diaria para los últimos N días hasta today. */
export function computeDailyMinutes(
  ctx: GameContext,
  daysCount: number = 7,
): DailyMinutesPoint[] {
  const points: DailyMinutesPoint[] = [];
  const startDay = addDays(ctx.today, -(daysCount - 1));
  const days = eachDay(startDay, ctx.today);

  for (const d of days) {
    const list = ctx.activities.filter((a) => a.occurredOn === d);
    let workoutsMin = 0;
    let runsMin = 0;
    let restMin = 0;

    for (const a of list) {
      const m = Math.round(safeNumber(a.durationSeconds) / 60);
      if (isWorkout(a)) workoutsMin += m;
      else if (isRun(a)) runsMin += m;
      else restMin += m;
    }

    const [yyyy, mm, dd] = d.split('-').map(Number);
    const dateObj = new Date(yyyy, mm - 1, dd);
    const dayLabel = `${DAY_NAMES[dateObj.getDay()]} ${dd}`;

    points.push({
      date: d,
      label: dayLabel,
      workoutsMin,
      runsMin,
      restMin,
      totalMin: workoutsMin + runsMin + restMin,
      isVacation: isOnVacation(d, ctx.vacations),
    });
  }

  return points;
}

/** Agrupación semanal para las últimas N semanas. */
export function computeWeeklyHistory(
  ctx: GameContext,
  weeksCount: number = 8,
): WeeklyDataPoint[] {
  const points: WeeklyDataPoint[] = [];
  const currentWeekStart = weekStart(ctx.today);

  for (let i = weeksCount - 1; i >= 0; i--) {
    const ws = addDays(currentWeekStart, -i * 7);
    const we = weekEnd(ws);
    const wp = weekProgress(ctx, ws);

    const inWeek = ctx.activities.filter((a) => a.occurredOn >= ws && a.occurredOn <= we);
    let workoutsMin = 0;
    let runsMin = 0;
    let restMin = 0;
    let calories = 0;

    for (const a of inWeek) {
      const m = Math.round(safeNumber(a.durationSeconds) / 60);
      if (isWorkout(a)) workoutsMin += m;
      else if (isRun(a)) runsMin += m;
      else restMin += m;

      if (a.caloriesKcal) calories += safeNumber(a.caloriesKcal);
    }

    const [, wsM, wsD] = ws.split('-').map(Number);
    const label = `${wsD.toString().padStart(2, '0')}/${wsM.toString().padStart(2, '0')}`;

    points.push({
      weekStart: ws,
      weekEnd: we,
      label,
      workouts: wp.workouts,
      runs: wp.runs,
      workoutsMin,
      runsMin,
      restMin,
      totalMin: workoutsMin + runsMin + restMin,
      km: Math.round(wp.km * 10) / 10,
      calories: Math.round(calories),
      met: wp.met,
      paused: wp.paused,
    });
  }

  return points;
}

/** Historial de ritmo para corridas con distancia. */
export function computePaceHistory(ctx: GameContext): PacePoint[] {
  const runsWithKm = ctx.activities
    .filter((a) => isRun(a) && safeNumber(a.distanceKm) > 0 && safeNumber(a.durationSeconds) > 0)
    .sort((a, b) => (a.occurredOn < b.occurredOn ? -1 : 1));

  return runsWithKm.map((a) => {
    const km = safeNumber(a.distanceKm);
    const durationMin = safeNumber(a.durationSeconds) / 60;
    const paceMinKm = durationMin / km;
    const [, mm, dd] = a.occurredOn.split('-').map(Number);

    return {
      id: a.id,
      date: a.occurredOn,
      label: `${dd.toString().padStart(2, '0')}/${mm.toString().padStart(2, '0')}`,
      distanceKm: Math.round(km * 100) / 100,
      durationMinutes: Math.round(durationMin),
      paceMinKm: Math.round(paceMinKm * 100) / 100,
      paceFormatted: formatPace(paceMinKm),
      location: a.runLocation === 'cinta' ? 'Cinta' : a.runLocation === 'calle' ? 'Calle' : 'Corrida',
      feeling: a.feeling ?? null,
    };
  });
}

/** Distribución por tipo de actividad. */
export function computeTypeDistribution(ctx: GameContext): TypeDistributionPoint[] {
  let workoutsCount = 0;
  let workoutsMin = 0;
  let treadmillRunsCount = 0;
  let treadmillRunsMin = 0;
  let outdoorRunsCount = 0;
  let outdoorRunsMin = 0;
  let genericRunsCount = 0;
  let genericRunsMin = 0;
  let activeRestCount = 0;
  let activeRestMin = 0;

  for (const a of ctx.activities) {
    const m = Math.round(safeNumber(a.durationSeconds) / 60);
    if (isWorkout(a)) {
      workoutsCount++;
      workoutsMin += m;
    } else if (isRun(a)) {
      if (a.runLocation === 'cinta') {
        treadmillRunsCount++;
        treadmillRunsMin += m;
      } else if (a.runLocation === 'calle') {
        outdoorRunsCount++;
        outdoorRunsMin += m;
      } else {
        genericRunsCount++;
        genericRunsMin += m;
      }
    } else {
      activeRestCount++;
      activeRestMin += m;
    }
  }

  const result: TypeDistributionPoint[] = [];

  if (workoutsCount > 0) {
    result.push({
      name: 'Entrenamientos',
      value: workoutsCount,
      minutes: workoutsMin,
      color: '#22c55e',
    });
  }
  if (treadmillRunsCount > 0) {
    result.push({
      name: 'Corrida (Cinta)',
      value: treadmillRunsCount,
      minutes: treadmillRunsMin,
      color: '#06b6d4',
    });
  }
  if (outdoorRunsCount > 0) {
    result.push({
      name: 'Corrida (Calle)',
      value: outdoorRunsCount,
      minutes: outdoorRunsMin,
      color: '#3b82f6',
    });
  }
  if (genericRunsCount > 0) {
    result.push({
      name: 'Corridas',
      value: genericRunsCount,
      minutes: genericRunsMin,
      color: '#0ea5e9',
    });
  }
  if (activeRestCount > 0) {
    result.push({
      name: 'Descanso activo',
      value: activeRestCount,
      minutes: activeRestMin,
      color: '#a855f7',
    });
  }

  return result;
}

/** Tendencia de sensación (1-5). */
export function computeFeelingTrend(ctx: GameContext): FeelingPoint[] {
  return ctx.activities
    .filter((a) => a.feeling != null && a.feeling >= 1 && a.feeling <= 5)
    .sort((a, b) => (a.occurredOn < b.occurredOn ? -1 : 1))
    .slice(-15)
    .map((a) => {
      const [, mm, dd] = a.occurredOn.split('-').map(Number);
      return {
        date: a.occurredOn,
        label: `${dd.toString().padStart(2, '0')}/${mm.toString().padStart(2, '0')}`,
        feeling: a.feeling!,
        type: isWorkout(a) ? 'Entreno' : isRun(a) ? 'Corrida' : 'Descanso',
      };
    });
}

/** Récords personales calculados del historial. */
export function computePersonalRecords(ctx: GameContext): PersonalRecords {
  const streak = computeStreak(ctx);
  const runs = ctx.activities.filter(isRun);

  let longestRunMinutes = 0;
  let longestRunKm = 0;
  let bestPaceMinKm: number | null = null;
  let maxRoundsAmrap = 0;

  for (const r of runs) {
    const min = Math.round(safeNumber(r.durationSeconds) / 60);
    const km = safeNumber(r.distanceKm);
    if (min > longestRunMinutes) longestRunMinutes = min;
    if (km > longestRunKm) longestRunKm = km;
    if (km > 0 && min > 0) {
      const pace = min / km;
      if (bestPaceMinKm === null || pace < bestPaceMinKm) {
        bestPaceMinKm = pace;
      }
    }
  }

  for (const a of ctx.activities) {
    if (a.roundsTotal && a.roundsTotal > maxRoundsAmrap) {
      maxRoundsAmrap = a.roundsTotal;
    }
  }

  // Semana más activa
  const weeks = computeWeeklyHistory(ctx, 24);
  let mostActiveWeekMinutes = 0;
  let mostActiveWeekLabel: string | null = null;

  for (const w of weeks) {
    if (w.totalMin > mostActiveWeekMinutes) {
      mostActiveWeekMinutes = w.totalMin;
      mostActiveWeekLabel = w.label;
    }
  }

  return {
    bestStreakDays: streak.best,
    longestRunMinutes,
    longestRunKm: Math.round(longestRunKm * 100) / 100,
    bestPaceMinKm: bestPaceMinKm ? Math.round(bestPaceMinKm * 100) / 100 : null,
    bestPaceFormatted: bestPaceMinKm ? formatPace(bestPaceMinKm) : null,
    maxRoundsAmrap,
    mostActiveWeekMinutes,
    mostActiveWeekLabel,
  };
}

/** Grilla para el heatmap mensual (mes actual). */
export function computeMonthlyHeatmap(ctx: GameContext, targetMonthDate: DateKey = ctx.today): HeatmapDay[] {
  const [year, month] = targetMonthDate.split('-').map(Number);
  const firstOfMonth = `${year}-${month.toString().padStart(2, '0')}-01`;
  const lastDayNumber = new Date(year, month, 0).getDate();
  const lastOfMonth = `${year}-${month.toString().padStart(2, '0')}-${lastDayNumber.toString().padStart(2, '0')}`;

  // Start at Monday of the first week of the month
  const gridStart = weekStart(firstOfMonth);
  // End at Sunday of the last week of the month
  const gridEnd = weekEnd(lastOfMonth);

  const days = eachDay(gridStart, gridEnd);
  const minutesByDay = new Map<string, { minutes: number; count: number }>();

  for (const a of ctx.activities) {
    const cur = minutesByDay.get(a.occurredOn) ?? { minutes: 0, count: 0 };
    cur.minutes += Math.round(safeNumber(a.durationSeconds) / 60);
    cur.count += 1;
    minutesByDay.set(a.occurredOn, cur);
  }

  return days.map((d) => {
    const [y, m, dayNum] = d.split('-').map(Number);
    const dateObj = new Date(y, m - 1, dayNum);
    // Sunday is 0 in JS, map to Monday = 0 ... Sunday = 6
    const jsDay = dateObj.getDay();
    const dayOfWeek = jsDay === 0 ? 6 : jsDay - 1;
    const isCurrentMonth = m === month;
    const isToday = d === ctx.today;
    const isFuture = d > ctx.today;
    const stats = minutesByDay.get(d) ?? { minutes: 0, count: 0 };
    const min = stats.minutes;

    let intensity: HeatmapDay['intensity'] = 0;
    if (min > 45) intensity = 4;
    else if (min >= 30) intensity = 3;
    else if (min >= 15) intensity = 2;
    else if (min > 0) intensity = 1;

    return {
      date: d,
      dayOfMonth: dayNum,
      dayOfWeek,
      isCurrentMonth,
      isToday,
      isFuture,
      isVacation: isOnVacation(d, ctx.vacations),
      minutes: min,
      activitiesCount: stats.count,
      intensity,
    };
  });
}

/** Resumen global para Analíticas. */
export function computeAnalyticsSummary(ctx: GameContext): AnalyticsSummary {
  const xp = computeXp(ctx);
  const level = levelFromXp(xp.total);
  const streak = computeStreak(ctx);
  const weekly = computeWeeklyStreak(ctx);
  const thisWeek = weekProgress(ctx, ctx.today);
  const prevWeekStart = addDays(weekStart(ctx.today), -7);
  const prevWeek = weekProgress(ctx, prevWeekStart);

  let totalMinutes = 0;
  let totalKm = 0;
  let totalCalories = 0;
  let totalWorkouts = 0;
  let totalRuns = 0;
  let totalActiveRest = 0;

  for (const a of ctx.activities) {
    totalMinutes += Math.round(safeNumber(a.durationSeconds) / 60);
    if (a.distanceKm) totalKm += safeNumber(a.distanceKm);
    if (a.caloriesKcal) totalCalories += safeNumber(a.caloriesKcal);
    if (isWorkout(a)) totalWorkouts++;
    else if (isRun(a)) totalRuns++;
    else totalActiveRest++;
  }

  return {
    totalXp: xp.total,
    level,
    currentStreak: streak.current,
    bestStreak: streak.best,
    currentWeeklyStreak: weekly.current,
    bestWeeklyStreak: weekly.best,
    totalActivities: ctx.activities.length,
    totalWorkouts,
    totalRuns,
    totalActiveRest,
    totalMinutes,
    totalKm: Math.round(totalKm * 10) / 10,
    totalCalories: Math.round(totalCalories),
    thisWeek,
    prevWeek,
    records: computePersonalRecords(ctx),
  };
}
