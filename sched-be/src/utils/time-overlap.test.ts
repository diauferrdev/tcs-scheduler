import { describe, expect, test } from 'bun:test';
import { isAfternoonPeriod, isMorningPeriod, timeRangesOverlap } from './time-overlap';

describe('isMorningPeriod', () => {
  test('start of window (09:00) is morning', () => {
    expect(isMorningPeriod('09:00')).toBe(true);
  });
  test('inside window (11:30) is morning', () => {
    expect(isMorningPeriod('11:30')).toBe(true);
  });
  test('end boundary (13:00) is NOT morning', () => {
    expect(isMorningPeriod('13:00')).toBe(false);
  });
  test('before window (08:59) is NOT morning', () => {
    expect(isMorningPeriod('08:30')).toBe(false);
  });
});

describe('isAfternoonPeriod', () => {
  test('start of window (13:00) is afternoon', () => {
    expect(isAfternoonPeriod('13:00')).toBe(true);
  });
  test('inside window (16:00) is afternoon', () => {
    expect(isAfternoonPeriod('16:00')).toBe(true);
  });
  test('end boundary (17:00) is NOT afternoon', () => {
    expect(isAfternoonPeriod('17:00')).toBe(false);
  });
  test('morning time (10:00) is NOT afternoon', () => {
    expect(isAfternoonPeriod('10:00')).toBe(false);
  });
});

describe('timeRangesOverlap', () => {
  // 540 = 09:00, 600 = 10:00, 660 = 11:00 (minutes from midnight)
  test('identical ranges overlap', () => {
    expect(timeRangesOverlap(540, 1, 540, 1)).toBe(true);
  });
  test('partial overlap', () => {
    // 09:00-10:00 vs 09:30-10:30
    expect(timeRangesOverlap(540, 1, 570, 1)).toBe(true);
  });
  test('contained range overlaps', () => {
    // 09:00-12:00 vs 10:00-11:00
    expect(timeRangesOverlap(540, 3, 600, 1)).toBe(true);
  });
  test('back-to-back (touching boundary) does NOT overlap', () => {
    // 09:00-10:00 vs 10:00-11:00
    expect(timeRangesOverlap(540, 1, 600, 1)).toBe(false);
  });
  test('fully separate ranges do NOT overlap', () => {
    // 09:00-10:00 vs 14:00-15:00
    expect(timeRangesOverlap(540, 1, 840, 1)).toBe(false);
  });
  test('overlap is symmetric (order of args does not matter)', () => {
    expect(timeRangesOverlap(570, 1, 540, 1)).toBe(timeRangesOverlap(540, 1, 570, 1));
  });
});
