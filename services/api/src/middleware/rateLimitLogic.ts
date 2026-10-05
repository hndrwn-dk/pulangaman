/** Pure rate-limit policy — live location polling must not block account deletes. */

export function shouldBypassRateLimit(method: string): boolean {
  return method.toUpperCase() === 'DELETE';
}
