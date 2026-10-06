// @vitest-environment happy-dom
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { App } from '../src/app';
import { mountPhoneUi } from '../src/phone/ui';
import { KEYS, memoryStore } from '../src/storage';

const tick = () => new Promise((r) => setTimeout(r, 0));

describe('phone page', () => {
  let app: App;
  let root: HTMLElement;
  let store: ReturnType<typeof memoryStore>;

  beforeEach(async () => {
    document.body.innerHTML = '<main id="app"></main>';
    root = document.getElementById('app')!;
    store = memoryStore();
    app = new App({ bridge: null, store, makeTranscriber: () => ({ onSegment: null, start() {}, stop() {}, appendPcm16k() {} }) });
    await app.init();
    mountPhoneUi(root, app);
  });
  afterEach(() => app.dispose());

  const q = <T extends Element>(sel: string) => root.querySelector<T>(sel)!;
  const click = (sel: string) => q<HTMLButtonElement>(sel).click();

  it('prompts for a key, saves it masked and never renders it back', async () => {
    expect(q('#key-status').textContent).toMatch(/no key/i);
    const input = q<HTMLInputElement>('#api-key');
    expect(input.type).toBe('password');
    expect(input.getAttribute('autocomplete')).toBe('off');
    input.value = 'test-secret-value';
    q<HTMLFormElement>('#key-form').dispatchEvent(new Event('submit', { cancelable: true }));
    await tick();
    expect(store.data[KEYS.apiKey]).toBe('test-secret-value');
    expect(input.value).toBe('');
    expect(q('#key-status').textContent).toMatch(/saved/i);
    expect(document.body.innerHTML).not.toContain('test-secret-value');
  });

  it('start, pause and end drive the session and the lens preview', async () => {
    expect(q<HTMLButtonElement>('#end').disabled).toBe(true);
    click('#start');
    await tick();
    expect(app.state.live).toBe(true);
    expect(q('#preview').textContent).toContain('OpenAI key');
    expect(q<HTMLButtonElement>('#start').disabled).toBe(true);
    click('#pause');
    await tick();
    expect(app.state.paused).toBe(true);
    expect(q('#pause').textContent).toBe('Resume');
    click('#end');
    await tick();
    expect(app.state.live).toBe(false);
  });

  it('settings toggles and cue duration update prefs', async () => {
    const captions = q<HTMLInputElement>('#pref-captions');
    captions.checked = false;
    captions.dispatchEvent(new Event('change'));
    const dur = q<HTMLInputElement>('#pref-duration');
    dur.value = '10';
    dur.dispatchEvent(new Event('change'));
    await tick();
    expect(app.state.prefs.captionsOn).toBe(false);
    expect(app.state.prefs.cueDurationMillis).toBe(10_000);
    expect(JSON.parse(store.data[KEYS.prefs]!).captionsOn).toBe(false);
  });

  it('prep notes can be added, edited, picked for start and deleted', async () => {
    q<HTMLInputElement>('#note-title').value = 'Acme call';
    const text = q<HTMLTextAreaElement>('#note-text');
    expect(text.maxLength).toBe(5000);
    text.value = 'Budget is the key topic.';
    q<HTMLFormElement>('#note-form').dispatchEvent(new Event('submit', { cancelable: true }));
    await tick();
    expect(app.state.prepNotes.map((n) => n.title)).toEqual(['Acme call']);
    expect(q('#notes').textContent).toContain('Acme call');
    const picker = q<HTMLSelectElement>('#start-note');
    expect([...picker.options].map((o) => o.textContent)).toEqual(['No prep note', 'Acme call']);

    q<HTMLButtonElement>('#notes [data-edit]').click();
    expect(q<HTMLInputElement>('#note-title').value).toBe('Acme call');
    q<HTMLInputElement>('#note-title').value = 'Acme renewal';
    q<HTMLFormElement>('#note-form').dispatchEvent(new Event('submit', { cancelable: true }));
    await tick();
    expect(app.state.prepNotes.map((n) => n.title)).toEqual(['Acme renewal']);

    q<HTMLButtonElement>('#notes [data-delete]').click();
    await tick();
    expect(app.state.prepNotes).toEqual([]);
  });

  it('note text cannot inject markup', async () => {
    q<HTMLInputElement>('#note-title').value = '<img src=x onerror=alert(1)>';
    q<HTMLTextAreaElement>('#note-text').value = 'x';
    q<HTMLFormElement>('#note-form').dispatchEvent(new Event('submit', { cancelable: true }));
    await tick();
    expect(root.querySelector('#notes img')).toBeNull();
  });
});
