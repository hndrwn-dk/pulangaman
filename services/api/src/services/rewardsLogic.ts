export function nextStreak(params: {
  lastAwardDate: string | null;
  currentStreak: number;
  today: string;
}): number {
  if (params.lastAwardDate === params.today) {
    return params.currentStreak;
  }
  if (!params.lastAwardDate) {
    return 1;
  }
  const previous = new Date(`${params.lastAwardDate}T00:00:00Z`);
  const today = new Date(`${params.today}T00:00:00Z`);
  const dayMs = 24 * 60 * 60 * 1000;
  const deltaDays = Math.round((today.getTime() - previous.getTime()) / dayMs);
  if (deltaDays === 1) {
    return params.currentStreak + 1;
  }
  return 1;
}
