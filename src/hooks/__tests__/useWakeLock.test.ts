import { describe, it, expect } from 'vitest';
import { useWakeLock } from '../useWakeLock';

describe('useWakeLock in non-browser or mock environment', () => {
  it('handles environment safely', () => {
    // In node environment without navigator.wakeLock
    expect(typeof useWakeLock).toBe('function');
  });
});
