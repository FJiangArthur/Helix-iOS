// PCM helpers. Even Hub audio is 16 kHz s16le mono; OpenAI realtime `audio/pcm`
// is 24 kHz s16le mono, so frames are resampled 2:3 with linear interpolation.

/** Little-endian bytes -> samples (copies, so odd offsets are safe). */
export function bytesToPcm16(bytes: Uint8Array): Int16Array {
  const n = bytes.length >> 1;
  const out = new Int16Array(n);
  const dv = new DataView(bytes.buffer, bytes.byteOffset, n * 2);
  for (let i = 0; i < n; i++) out[i] = dv.getInt16(i * 2, true);
  return out;
}

export function pcm16ToBytes(samples: Int16Array): Uint8Array {
  const out = new Uint8Array(samples.length * 2);
  const dv = new DataView(out.buffer);
  for (let i = 0; i < samples.length; i++) dv.setInt16(i * 2, samples[i]!, true);
  return out;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(bin);
}

/**
 * Streaming 16 kHz -> 24 kHz linear resampler. Output sample k sits at input
 * position k·2/3; positions are tracked in exact thirds so chunk boundaries
 * never drift. A sample that needs the next chunk's first input is deferred.
 */
export class Resampler16kTo24k {
  private posThirds = 0; // relative to the current chunk start; may be -3..-1 (previous sample)
  private prev = 0;

  process(input: Int16Array): Int16Array {
    const n = input.length;
    if (n === 0) return new Int16Array(0);
    const out: number[] = [];
    const at = (i: number) => (i < 0 ? this.prev : input[i]!);
    for (;;) {
      const i = Math.floor(this.posThirds / 3);
      const f = (this.posThirds - i * 3) / 3;
      if (f === 0 ? i > n - 1 : i + 1 > n - 1) break;
      const v = f === 0 ? at(i) : at(i) * (1 - f) + at(i + 1) * f;
      out.push(Math.max(-32768, Math.min(32767, Math.round(v))));
      this.posThirds += 2;
    }
    this.posThirds -= n * 3;
    this.prev = input[n - 1]!;
    return Int16Array.from(out);
  }

  reset(): void {
    this.posThirds = 0;
    this.prev = 0;
  }
}
