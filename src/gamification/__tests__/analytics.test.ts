import { describe, expect, it } from 'vitest';
import { ctx, rest, run, workout } from './helpers';
import {
  computeAnalyticsSummary,
  computeDailyMinutes,
  computeMonthlyHeatmap,
  computePaceHistory,
  computePersonalRecords,
  computeTypeDistribution,
  computeWeeklyHistory,
} from '../analytics';

describe('Analytics Calculations', () => {
  it('computes summary and week comparison accurately', () => {
    const context = ctx(
      '2026-03-15',
      [
        workout('2026-03-09', { durationSeconds: 40 * 60 }),
        run('2026-03-10', { distanceKm: 5, durationSeconds: 30 * 60, feeling: 4 }),
        rest('2026-03-11'),
        workout('2026-03-02', { durationSeconds: 45 * 60 }),
      ],
      [],
      { weightKg: 65 },
    );

    const summary = computeAnalyticsSummary(context);
    expect(summary.totalActivities).toBe(4);
    expect(summary.totalWorkouts).toBe(2);
    expect(summary.totalRuns).toBe(1);
    expect(summary.totalActiveRest).toBe(1);
    expect(summary.totalMinutes).toBe(40 + 30 + 10 + 45);
    expect(summary.totalKm).toBe(5);
    expect(summary.thisWeek.workouts).toBe(1);
    expect(summary.prevWeek.workouts).toBe(1);
  });

  it('computes daily minutes breakdown and weekly history', () => {
    const context = ctx(
      '2026-03-15',
      [
        workout('2026-03-15', { durationSeconds: 35 * 60 }),
        run('2026-03-15', { distanceKm: 4, durationSeconds: 25 * 60 }),
      ],
      [],
    );

    const daily = computeDailyMinutes(context, 7);
    expect(daily.length).toBe(7);
    const todayPoint = daily[daily.length - 1];
    expect(todayPoint.workoutsMin).toBe(35);
    expect(todayPoint.runsMin).toBe(25);
    expect(todayPoint.totalMin).toBe(60);

    const weekly = computeWeeklyHistory(context, 4);
    expect(weekly.length).toBe(4);
    expect(weekly[weekly.length - 1].workouts).toBe(1);
    expect(weekly[weekly.length - 1].runs).toBe(1);
  });

  it('computes pace history and personal records', () => {
    const context = ctx(
      '2026-03-15',
      [
        run('2026-03-10', { distanceKm: 5, durationSeconds: 25 * 60, runLocation: 'calle' }), // 5:00 min/km
        run('2026-03-12', { distanceKm: 6, durationSeconds: 36 * 60, runLocation: 'cinta' }), // 6:00 min/km
      ],
      [],
    );

    const pace = computePaceHistory(context);
    expect(pace.length).toBe(2);
    expect(pace[0].paceMinKm).toBe(5);
    expect(pace[0].paceFormatted).toContain('5:00');
    expect(pace[1].paceMinKm).toBe(6);

    const records = computePersonalRecords(context);
    expect(records.longestRunKm).toBe(6);
    expect(records.longestRunMinutes).toBe(36);
    expect(records.bestPaceMinKm).toBe(5);
  });

  it('computes monthly heatmap grid for March 2026', () => {
    const context = ctx(
      '2026-03-15',
      [
        workout('2026-03-15', { durationSeconds: 50 * 60 }),
      ],
      [],
    );

    const heatmap = computeMonthlyHeatmap(context, '2026-03-15');
    expect(heatmap.length).toBeGreaterThanOrEqual(28);
    const day15 = heatmap.find((h) => h.date === '2026-03-15');
    expect(day15).toBeDefined();
    expect(day15?.intensity).toBe(4); // > 45 min
    expect(day15?.isToday).toBe(true);
  });

  it('computes type distribution', () => {
    const context = ctx(
      '2026-03-15',
      [
        workout('2026-03-10', { durationSeconds: 30 * 60 }),
        run('2026-03-11', { durationSeconds: 20 * 60, runLocation: 'cinta' }),
        rest('2026-03-12'),
      ],
      [],
    );

    const dist = computeTypeDistribution(context);
    expect(dist.length).toBe(3);
    expect(dist.find((d) => d.name === 'Entrenamientos')?.value).toBe(1);
    expect(dist.find((d) => d.name === 'Corrida (Cinta)')?.value).toBe(1);
    expect(dist.find((d) => d.name === 'Descanso activo')?.value).toBe(1);
  });
});
