export function startOfRange(range: 'week' | 'month', now = new Date()) {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  if (range === 'month') {
    start.setDate(1);
    return start;
  }

  const day = start.getDay() || 7;
  start.setDate(start.getDate() - day + 1);
  return start;
}

export function startOfToday(now = new Date()) {
  const start = new Date(now);
  start.setHours(0, 0, 0, 0);
  return start;
}
