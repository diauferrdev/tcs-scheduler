// Pure time-period helpers for booking conflict logic.
// Extracted so the rules can be unit-tested without a database.
//
// Office day is split into two periods:
//   morning   = 09:00–13:00
//   afternoon = 13:00–17:00

/** True if the start time (HH:mm) falls in the morning period (09:00–13:00). */
export function isMorningPeriod(startTime: string): boolean {
  const hour = parseInt(startTime.split(':')[0]);
  return hour >= 9 && hour < 13;
}

/** True if the start time (HH:mm) falls in the afternoon period (13:00–17:00). */
export function isAfternoonPeriod(startTime: string): boolean {
  const hour = parseInt(startTime.split(':')[0]);
  return hour >= 13 && hour < 17;
}

/**
 * True if two time ranges overlap. Ranges are half-open [start, end):
 * touching at the boundary (one ends exactly when the other starts) is NOT an overlap.
 *
 * @param start1Minutes  range 1 start, in minutes from midnight
 * @param duration1Hours range 1 duration, in hours
 * @param start2Minutes  range 2 start, in minutes from midnight
 * @param duration2Hours range 2 duration, in hours
 */
export function timeRangesOverlap(
  start1Minutes: number,
  duration1Hours: number,
  start2Minutes: number,
  duration2Hours: number
): boolean {
  const end1Minutes = start1Minutes + duration1Hours * 60;
  const end2Minutes = start2Minutes + duration2Hours * 60;

  return start1Minutes < end2Minutes && start2Minutes < end1Minutes;
}
