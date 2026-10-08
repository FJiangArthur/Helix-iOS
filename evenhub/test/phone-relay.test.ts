// @vitest-environment happy-dom
// Phone page 0.3: relay settings, mode selector, display controls, Ask box.
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { App } from '../src/app';
import { mountPhoneUi } from '../src/phone/ui';
import { KEYS, memoryStore } from '../src/storage';
import { fakeRelay, RELAY_KEY, RELAY_URL } from './fakeRelay';

const settle = async () => { for (let i = 0; i < 10; i++) await new Promise((r) => setTimeout(r, 0)); };

describe('phone page 0.3', () => {
  let app: App;
  let root: HTMLElement;
  let store: ReturnType<typeof memoryStore>;
  let relay: ReturnType<typeof fakeRelay>;

  beforeEach(async () => {
    document.body.innerHTML = '<main id="app"></main>';
    root = document.getElementById('app')!;
    store = memoryStore({ [KEYS.apiKey]: 'k' });
    relay = fakeRelay({ sse: ['data: {"delta":"Can"}\n\n', 'data: {"delta":"berra."}\n\n', 'data: {"done":true}\n\n'] });
    app = new App({
      bridge: null,
      store,
      relayFetch: relay.fetchFn,
      makeTranscriber: () => ({ onSegment: null, start() {}, stop() {}, appendPcm16k() {} }),
    });
    await app.init();
    mountPhoneUi(root, app);
  });
  afterEach(() => app.dispose());

  const q = <T extends Element>(sel: string) => root.querySelector<T>(sel)!;
  const submit = (sel: string) => q<HTMLFormElement>(sel).dispatchEvent(new Event('submit', { cancelable: true }));
  const change = (sel: string, value: string) => {
    const el = q<HTMLSelectElement | HTMLInputElement>(sel);
    el.value = value;
    el.dispatchEvent(new Event('change'));
  };

  it('saves the relay URL and a masked key that is never rendered back', async () => {
    const key = q<HTMLInputElement>('#relay-key');
    expect(key.type).toBe('password');
    expect(key.getAttribute('autocomplete')).toBe('off');
    q<HTMLInputElement>('#relay-url').value = RELAY_URL;
    key.value = RELAY_KEY;
    submit('#relay-form');
    await settle();
    expect(store.data[KEYS.relayUrl]).toBe(RELAY_URL);
    expect(store.data[KEYS.relayKey]).toBe(RELAY_KEY);
    expect(key.value).toBe('');
    expect(document.body.innerHTML).not.toContain(RELAY_KEY);
    expect(q('#relay-state').textContent).toMatch(/saved/i);
    expect(q<HTMLInputElement>('#relay-url').value).toBe(RELAY_URL);
  });

  it('test connection reports the relay version', async () => {
    await app.setRelay(RELAY_URL, RELAY_KEY);
    q<HTMLButtonElement>('#relay-test').click();
    await settle();
    expect(q('#relay-status').textContent).toMatch(/connected.*0\.3\.0/i);
  });

  it('mode selector offers Glasses / Phone / Display only and switches mode', async () => {
    const mode = q<HTMLSelectElement>('#mode');
    expect([...mode.options].map((o) => o.textContent)).toEqual(['Glasses mic', 'Phone mic', 'Display only']);
    expect(mode.value).toBe('GLASSES_MIC');
    change('#mode', 'DISPLAY_ONLY');
    await settle();
    expect(app.state.mode).toBe('DISPLAY_ONLY');
    expect(store.data[KEYS.mode]).toBe('DISPLAY_ONLY');
  });

  it('display controls set caption lines and brightness', async () => {
    expect(q<HTMLSelectElement>('#pref-lines').value).toBe('5');
    expect(q<HTMLSelectElement>('#pref-brightness').value).toBe('3');
    change('#pref-lines', '3');
    change('#pref-brightness', '1');
    await settle();
    expect(app.state.prefs.captionLines).toBe(3);
    expect(app.state.prefs.brightness).toBe(1);
    expect(JSON.parse(store.data[KEYS.prefs]!)).toMatchObject({ captionLines: 3, brightness: 1 });
  });

  it('Ask box streams the relay answer onto the page and the lens', async () => {
    await app.setRelay(RELAY_URL, RELAY_KEY);
    q<HTMLInputElement>('#ask-q').value = 'Capital of Australia?';
    q<HTMLInputElement>('#ask-deep').checked = true;
    submit('#ask-form');
    await settle();
    expect(JSON.parse(String(relay.of('/ask')[0]!.init.body))).toMatchObject({ question: 'Capital of Australia?', deep: true });
    expect(q('#ask-answer').textContent).toBe('Canberra.');
    expect(q('#preview').textContent).toContain('Canberra.');
  });
});
