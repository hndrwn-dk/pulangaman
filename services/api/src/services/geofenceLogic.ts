export type Presence = 'unknown' | 'inside' | 'outside';

export function nextPresence(params: {
  previous: Presence;
  distanceM: number;
  radiusM: number;
  hysteresisM: number;
}): Presence {
  const insideStrict = params.distanceM <= params.radiusM;
  const outsideStrict = params.distanceM > params.radiusM + params.hysteresisM;
  const { previous } = params;

  if (insideStrict && previous !== 'inside') {
    return 'inside';
  }
  if (outsideStrict && previous === 'inside') {
    return 'outside';
  }
  if (previous === 'unknown') {
    return insideStrict ? 'inside' : 'outside';
  }
  return previous;
}

export function shouldEmitZoneEvent(params: {
  previous: Presence;
  next: Presence;
  sinceLastEventMs: number;
  debounceMs: number;
}): boolean {
  // First GPS fix already inside a zone → notify parent once ("sudah di rumah").
  if (params.previous === 'unknown' && params.next === 'inside') {
    return true;
  }
  const isTransition = params.previous !== 'unknown' && params.next !== params.previous;
  if (!isTransition) {
    return false;
  }
  return params.sinceLastEventMs >= params.debounceMs;
}
