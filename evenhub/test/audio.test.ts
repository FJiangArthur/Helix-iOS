import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { bytesToBase64, pcm16ToBytes, Resampler16kTo24k } from '../src/audio/pcm';
import { RealtimeTranscriber, type SocketLike, realtimeSessionUpdate, REALTIME_URL, realtimeProtocols } from '../src/audio/realtime';
import { RoleTimeline, SegmentAssembler, type Segment } from '../src/audio/segments';
import { ChunkedTranscriber, encodeWav } from '../src/audio/chunked';
import { TranscriberSupervisor } from '../src/audio/supervisor';

const fixture: Record<string, unknown>[] = JSON.parse(readFileSync(new URL('./fixtures/realtime-events.json', import.meta.url), 'utf8'));

describe('Resampler16kTo24k', () => {
  it('produces 3 output samples per 2 input samples (one held back for the next chunk)', () => {
    const r = new Resampler16kTo24k();
    expect(r.process(new Int16Array(1600)).length).toBe(2399);
    expect(r.process(new Int16Array(1600)).length).toBe(2400);
  });

  it('interpolates linearly and keeps phase across chunks', () => {
    const ramp = Int16Array.from({ length: 8 }, (_, i) => i * 300);
    const whole = new Resampler16kTo24k().process(ramp);
    const r = new Resampler16kTo24k();
    const split = [...r.process(ramp.slice(0, 3)), ...r.process(ramp.slice(3))];
    expect(split).toEqual([...whole]);
    // output k sits at input position k*2/3 => value 200*k on a 300/sample ramp
    expect([...whole.slice(0, 7)]).toEqual([0, 200, 400, 600, 800, 1000, 1200]);
  });

  it('round-trips s16le bytes and base64', () => {
    const bytes = new Uint8Array([0x01, 0x00, 0xff, 0x7f, 0x00, 0x80]);
    const view = new Int16Array(bytes.buffer.slice(0));
    expect([...view]).toEqual([1, 32767, -32768]);
    expect([...pcm16ToBytes(view)]).toEqual([...bytes]);
    expect(bytesToBase64(new Uint8Array([104, 105]))).toBe('aGk=');
  });
});

describe('encodeWav', () => {
  it('writes a 44-byte RIFF header for 16 kHz mono s16le', () => {
    const pcm = new Uint8Array(3200);
    const wav = encodeWav(pcm, 16000);
    const dv = new DataView(wav.buffer);
    const ascii = (o: number) => String.fromCharCode(...wav.slice(o, o + 4));
    expect(wav.length).toBe(44 + 3200);
    expect(ascii(0)).toBe('RIFF');
    expect(dv.getUint32(4, true)).toBe(36 + 3200);
    expect(ascii(8)).toBe('WAVE');
    expect(ascii(12)).toBe('fmt ');
    expect(dv.getUint16(20, true)).toBe(1);
    expect(dv.getUint16(22, true)).toBe(1);
    expect(dv.getUint32(24, true)).toBe(16000);
    expect(dv.getUint32(28, true)).toBe(32000);
    expect(dv.getUint16(34, true)).toBe(16);
    expect(ascii(36)).toBe('data');
    expect(dv.getUint32(40, true)).toBe(3200);
  });
});

describe('RoleTimeline', () => {
  it('returns the majority role over a time span', () => {
    const t = new RoleTimeline();
    t.add(1000, 'other');
    t.add(500, 'self');
    t.add(500, 'self');
    expect(t.roleBetween(0, 1000)).toBe('other');
    expect(t.roleBetween(1200, 2000)).toBe('self');
    expect(t.roleBetween(900, 1300)).toBe('self');
    expect(new RoleTimeline().roleBetween(0, 10)).toBe('unknown');
  });
});

describe('SegmentAssembler', () => {
  it('assembles partials and finals from recorded realtime events', () => {
    const roles = new RoleTimeline();
    roles.add(1000, 'other');
    roles.add(1000, 'self');
    const out: Segment[] = [];
    const a = new SegmentAssembler(roles, (s) => out.push(s));
    fixture.forEach((e) => a.onServerEvent(e));
    expect(out.map((s) => [s.isFinal, s.text, s.role])).toEqual([
      [false, 'Hello,', 'other'],
      [false, 'Hello, how are', 'other'],
      [false, 'Hello, how are Fine', 'other'],
      [true, 'Hello, how are you?', 'other'],
      [false, 'Fine', 'self'],
      [true, 'Fine, thanks.', 'self'],
    ]);
  });
});

class FakeSocket implements SocketLike {
  sent: string[] = [];
  readyState = 0;
  onopen: (() => void) | null = null;
  onmessage: ((ev: { data: unknown }) => void) | null = null;
  onerror: ((ev: unknown) => void) | null = null;
  onclose: ((ev: { code: number; reason: string }) => void) | null = null;
  closed = false;
  send(data: string) { this.sent.push(data); }
  close() { this.closed = true; this.readyState = 3; }
  open() { this.readyState = 1; this.onopen?.(); }
  emit(e: unknown) { this.onmessage?.({ data: JSON.stringify(e) }); }
}

describe('RealtimeTranscriber', () => {
  it('connects with GA transcription subprotocols and configures the session', () => {
    const sockets: Array<{ url: string; protocols: string[]; s: FakeSocket }> = [];
    const t = new RealtimeTranscriber({
      apiKey: 'test-key',
      model: 'gpt-4o-mini-transcribe',
      socketFactory: (url, protocols) => { const s = new FakeSocket(); sockets.push({ url, protocols, s }); return s; },
    });
    const segs: Segment[] = [];
    t.onSegment = (s) => segs.push(s);
    t.start();
    expect(sockets[0]!.url).toBe(REALTIME_URL);
    expect(sockets[0]!.protocols).toEqual(realtimeProtocols('test-key'));
    // audio before open is buffered, not lost
    t.appendPcm16k(new Uint8Array(3200), 'other');
    sockets[0]!.s.open();
    const sent = sockets[0]!.s.sent.map((m) => JSON.parse(m));
    expect(sent[0]).toEqual(realtimeSessionUpdate('gpt-4o-mini-transcribe'));
    expect(sent[0].session.audio.input.format).toEqual({ type: 'audio/pcm', rate: 24000 });
    expect(sent[0].session.audio.input.turn_detection.type).toBe('server_vad');
    expect(sent[1].type).toBe('input_audio_buffer.append');
    expect(Buffer.from(sent[1].audio, 'base64').length).toBe(4798); // 1600 samples -> 2399 @ 24k (last waits for the next frame)
    fixture.forEach((e) => sockets[0]!.s.emit(e));
    expect(segs.filter((s) => s.isFinal).map((s) => s.text)).toEqual(['Hello, how are you?', 'Fine, thanks.']);
    t.stop();
    expect(sockets[0]!.s.closed).toBe(true);
  });

  it('reports one failure per connection (error then close), and none after stop', () => {
    const s = new FakeSocket();
    const t = new RealtimeTranscriber({ apiKey: 'k', model: 'gpt-4o-mini-transcribe', socketFactory: () => s });
    const failures: string[] = [];
    t.onFailure = (why) => failures.push(why);
    t.start();
    s.open();
    s.emit({ type: 'error', error: { message: 'bad key' } });
    s.onclose?.({ code: 1006, reason: '' });
    expect(failures).toEqual(['bad key']);
    const s2 = new FakeSocket();
    const t2 = new RealtimeTranscriber({ apiKey: 'k', model: 'gpt-4o-mini-transcribe', socketFactory: () => s2 });
    t2.onFailure = (why) => failures.push(why);
    t2.start(); s2.open(); s2.onclose?.({ code: 1006, reason: '' });
    expect(failures).toEqual(['bad key', 'closed 1006']);
    const s3 = new FakeSocket();
    const t3 = new RealtimeTranscriber({ apiKey: 'k', model: 'gpt-4o-mini-transcribe', socketFactory: () => s3 });
    t3.onFailure = (why) => failures.push(why);
    t3.start(); s3.open(); t3.stop(); s3.onclose?.({ code: 1000, reason: '' });
    expect(failures.length).toBe(2);
  });
});

describe('ChunkedTranscriber', () => {
  it('posts 3 s WAV chunks to the transcription endpoint and emits finals', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const fetchFn = async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(JSON.stringify({ text: 'chunk text' }), { status: 200 });
    };
    const t = new ChunkedTranscriber({ apiKey: 'k', model: 'gpt-4o-mini-transcribe', fetchFn, chunkMillis: 3000 });
    const segs: Segment[] = [];
    t.onSegment = (s) => segs.push(s);
    t.start();
    for (let i = 0; i < 29; i++) t.appendPcm16k(new Uint8Array(3200), 'self');
    expect(calls.length).toBe(0);
    t.appendPcm16k(new Uint8Array(3200), 'self');
    await t.idle();
    expect(calls.length).toBe(1);
    expect(calls[0]!.url).toBe('https://api.openai.com/v1/audio/transcriptions');
    expect((calls[0]!.init.headers as Record<string, string>).Authorization).toBe('Bearer k');
    const form = calls[0]!.init.body as FormData;
    expect(form.get('model')).toBe('gpt-4o-mini-transcribe');
    expect((form.get('file') as Blob).size).toBe(44 + 96000);
    expect(segs).toEqual([{ itemId: 'chunk-1', text: 'chunk text', isFinal: true, role: 'self' }]);
  });
});

describe('TranscriberSupervisor', () => {
  it('switches to the chunked fallback after the socket fails twice', () => {
    const made: string[] = [];
    const fake = (name: string) => {
      const t = { onSegment: null as any, onFailure: null as ((w: string) => void) | null, start: () => made.push(`start ${name}`), stop: () => made.push(`stop ${name}`), appendPcm16k: () => {} };
      return t;
    };
    const rts: ReturnType<typeof fake>[] = [];
    const sup = new TranscriberSupervisor({
      realtime: () => { const t = fake(`rt${rts.length}`); rts.push(t); return t; },
      chunked: () => fake('chunked'),
    });
    const modes: string[] = [];
    sup.onMode = (m) => modes.push(m);
    sup.start();
    rts[0]!.onFailure!('closed 1006');
    rts[1]!.onFailure!('closed 1006');
    expect(made).toEqual(['start rt0', 'stop rt0', 'start rt1', 'stop rt1', 'start chunked']);
    expect(modes).toEqual(['realtime', 'realtime', 'chunked']);
  });
});
