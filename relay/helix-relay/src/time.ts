/** Local calendar day (YYYY-MM-DD) of an instant in `timeZone`. */
export function dayKey(ms: number, timeZone: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(ms);
}

/** Start of the local day containing `ms`, as epoch ms (DST-safe to the minute). */
export function startOfLocalDay(ms: number, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
  }).formatToParts(ms);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  const sinceMidnight = (get('hour') * 3600 + get('minute') * 60 + get('second')) * 1000 + (ms % 1000);
  return ms - sinceMidnight;
}

/** Short local clock label: "2pm", "2:30pm". */
export function clockLabel(ms: number, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone, hour: 'numeric', minute: '2-digit', hour12: true }).formatToParts(ms);
  const hour = parts.find((p) => p.type === 'hour')?.value ?? '';
  const minute = parts.find((p) => p.type === 'minute')?.value ?? '00';
  const ampm = (parts.find((p) => p.type === 'dayPeriod')?.value ?? '').toLowerCase();
  return `${hour}${minute === '00' ? '' : `:${minute}`}${ampm}`;
}
