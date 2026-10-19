import { describe, expect, it } from 'vitest';
import { addDays, toDateKey } from '../dates';
import { comebackStatus, isOnVacation, vacationStatus } from '../vacations';
import type { VacationPeriod } from '../../types/gamification';

describe('Vacations logic integration', () => {
  it('handles active vacation and endOn convention correctly', () => {
    const today = toDateKey(new Date());
    const yesterday = addDays(today, -1);
    const startOn = addDays(today, -5);

    const activeVacation: VacationPeriod = {
      id: 'vac-1',
      startOn,
      endOn: null,
    };

    // While active:
    expect(isOnVacation(today, [activeVacation])).toBe(true);
    const vStat = vacationStatus(today, [activeVacation]);
    expect(vStat.active).toBe(true);
    expect(vStat.lengthDays).toBe(6);

    // When ended today (convention: endOn = yesterday):
    const endedVacation: VacationPeriod = {
      ...activeVacation,
      endOn: yesterday,
    };

    expect(isOnVacation(today, [endedVacation])).toBe(false);
    const cb = comebackStatus(today, [endedVacation]);
    expect(cb.active).toBe(true);
    expect(cb.dayNumber).toBe(1);
    expect(cb.daysLeft).toBe(3);
  });
});
