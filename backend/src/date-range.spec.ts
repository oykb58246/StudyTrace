import { startOfRange, startOfToday } from './common/date-range';

describe('date range helpers', () => {
  it('returns local start of today', () => {
    const result = startOfToday(new Date('2026-05-06T12:30:00'));
    expect(result.getHours()).toBe(0);
    expect(result.getMinutes()).toBe(0);
  });

  it('returns monday for week range', () => {
    const result = startOfRange('week', new Date('2026-05-06T12:30:00'));
    expect(result.getDay()).toBe(1);
  });

  it('returns first day for month range', () => {
    const result = startOfRange('month', new Date('2026-05-06T12:30:00'));
    expect(result.getDate()).toBe(1);
  });
});
