import type { Activity, VacationPeriod } from '../../types/gamification';
import type { GameContext } from '../activities';

let counter = 0;

export function workout(day: string, extra: Partial<Activity> = {}): Activity {
  counter += 1;
  return {
    id: `w-${counter}`,
    type: 'workout_day',
    occurredOn: day,
    durationSeconds: 45 * 60,
    blocksCompleted: 3,
    xpEarned: 100,
    ...extra,
  };
}

export function run(day: string, extra: Partial<Activity> = {}): Activity {
  counter += 1;
  return {
    id: `r-${counter}`,
    type: 'run',
    occurredOn: day,
    durationSeconds: 30 * 60,
    xpEarned: 60,
    ...extra,
  };
}

export function rest(day: string, extra: Partial<Activity> = {}): Activity {
  counter += 1;
  return {
    id: `a-${counter}`,
    type: 'active_rest',
    occurredOn: day,
    durationSeconds: 10 * 60,
    xpEarned: 20,
    ...extra,
  };
}

export function vacation(startOn: string, endOn: string | null): VacationPeriod {
  counter += 1;
  return { id: `v-${counter}`, startOn, endOn };
}

export function ctx(
  today: string,
  activities: Activity[] = [],
  vacations: VacationPeriod[] = [],
  extra: Partial<GameContext> = {},
): GameContext {
  return { today, activities, vacations, ...extra };
}

/** Un descanso activo por cada día indicado. */
export function activeDays(days: string[]): Activity[] {
  return days.map((d) => rest(d));
}
