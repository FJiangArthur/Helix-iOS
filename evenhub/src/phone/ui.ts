// Phone-side page (the Even app WebView): key, session controls, settings,
// Prep Notes and a live preview of the lens. Static markup only; every piece
// of user or model text goes in via textContent.
import type { App, AppState } from '../app';
import { PREP_NOTE_MAX_CHARS } from '../storage';
import './ui.css';

const TEMPLATE = `
<header class="bar">
  <h1>Helix Live</h1>
  <p id="status" role="status" aria-live="polite"></p>
</header>

<section aria-labelledby="h-key">
  <h2 id="h-key">OpenAI key</h2>
  <p id="key-status"></p>
  <form id="key-form" class="row">
    <label for="api-key" class="sr-only">OpenAI API key</label>
    <input id="api-key" type="password" autocomplete="off" spellcheck="false" placeholder="Paste your OpenAI API key" />
    <button type="submit">Save key</button>
    <button type="button" id="key-clear" class="quiet">Remove</button>
  </form>
  <p class="hint">Stored only on this phone. Audio and transcript text go to api.openai.com.</p>
</section>

<section aria-labelledby="h-session">
  <h2 id="h-session">Session</h2>
  <div class="row">
    <label for="start-note">Prep note</label>
    <select id="start-note"></select>
  </div>
  <div class="row buttons">
    <button id="start" type="button">Start</button>
    <button id="pause" type="button">Pause</button>
    <button id="end" type="button" class="danger">End</button>
  </div>
  <h3>On the lens</h3>
  <pre id="preview" aria-live="polite" aria-label="Glasses preview"></pre>
</section>

<section aria-labelledby="h-settings">
  <h2 id="h-settings">Settings</h2>
  <label class="check"><input id="pref-captions" type="checkbox" /> Captions</label>
  <label class="check"><input id="pref-cues" type="checkbox" /> AI cues</label>
  <label class="check"><input id="pref-popup" type="checkbox" /> Auto-popup cues</label>
  <div class="row">
    <label for="pref-duration">Cue duration (s)</label>
    <input id="pref-duration" type="number" min="3" max="15" step="1" inputmode="numeric" />
  </div>
  <div class="row">
    <label for="pref-source">Microphone</label>
    <select id="pref-source">
      <option value="glasses">Glasses</option>
      <option value="phone">Phone</option>
    </select>
  </div>
</section>

<section aria-labelledby="h-notes">
  <h2 id="h-notes">Prep Notes</h2>
  <ul id="notes"></ul>
  <form id="note-form">
    <input id="note-id" type="hidden" />
    <label for="note-title">Title</label>
    <input id="note-title" type="text" maxlength="80" />
    <label for="note-text">Notes <span id="note-count" class="hint"></span></label>
    <textarea id="note-text" rows="6"></textarea>
    <div class="row buttons">
      <button type="submit" id="note-save">Add note</button>
      <button type="button" id="note-cancel" class="quiet">Clear</button>
    </div>
  </form>
</section>
`;

function option(text: string, value: string): HTMLOptionElement {
  const o = document.createElement('option');
  o.textContent = text;
  o.value = value;
  return o;
}

let idCounter = 0;
const newId = () => `n${Date.now().toString(36)}${(idCounter++).toString(36)}`;

export function mountPhoneUi(root: HTMLElement, app: App): () => void {
  root.innerHTML = TEMPLATE;
  const $ = <T extends HTMLElement>(sel: string) => root.querySelector<T>(sel)!;

  const status = $('#status');
  const keyStatus = $('#key-status');
  const keyInput = $<HTMLInputElement>('#api-key');
  const startNote = $<HTMLSelectElement>('#start-note');
  const start = $<HTMLButtonElement>('#start');
  const pause = $<HTMLButtonElement>('#pause');
  const end = $<HTMLButtonElement>('#end');
  const preview = $('#preview');
  const captions = $<HTMLInputElement>('#pref-captions');
  const cues = $<HTMLInputElement>('#pref-cues');
  const popup = $<HTMLInputElement>('#pref-popup');
  const duration = $<HTMLInputElement>('#pref-duration');
  const source = $<HTMLSelectElement>('#pref-source');
  const notes = $<HTMLUListElement>('#notes');
  const noteId = $<HTMLInputElement>('#note-id');
  const noteTitle = $<HTMLInputElement>('#note-title');
  const noteText = $<HTMLTextAreaElement>('#note-text');
  const noteCount = $('#note-count');
  const noteSave = $<HTMLButtonElement>('#note-save');
  noteText.maxLength = PREP_NOTE_MAX_CHARS;

  $<HTMLFormElement>('#key-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const value = keyInput.value.trim();
    keyInput.value = '';
    if (value !== '') void app.setApiKey(value);
  });
  $('#key-clear').addEventListener('click', () => void app.setApiKey(''));

  start.addEventListener('click', () => void app.start(startNote.value || null));
  pause.addEventListener('click', () => void app.setPaused(!app.state.paused));
  end.addEventListener('click', () => void app.end());

  const savePrefs = () =>
    void app.updatePrefs({
      captionsOn: captions.checked,
      cuesOn: cues.checked,
      autoPopup: popup.checked,
      cueDurationMillis: (Number(duration.value) || 6) * 1000,
    });
  for (const el of [captions, cues, popup, duration]) el.addEventListener('change', savePrefs);
  source.addEventListener('change', () => void app.setAudioSource(source.value === 'phone' ? 'phone' : 'glasses'));

  const resetNoteForm = () => {
    noteId.value = '';
    noteTitle.value = '';
    noteText.value = '';
    noteSave.textContent = 'Add note';
    updateCount();
  };
  const updateCount = () => { noteCount.textContent = `${noteText.value.length}/${PREP_NOTE_MAX_CHARS}`; };
  noteText.addEventListener('input', updateCount);
  $('#note-cancel').addEventListener('click', resetNoteForm);
  $<HTMLFormElement>('#note-form').addEventListener('submit', (e) => {
    e.preventDefault();
    if (noteTitle.value.trim() === '' && noteText.value.trim() === '') return;
    void app.savePrepNote({ id: noteId.value || newId(), title: noteTitle.value, text: noteText.value });
    resetNoteForm();
  });
  notes.addEventListener('click', (e) => {
    const btn = (e.target as HTMLElement).closest('button');
    if (!btn) return;
    const id = btn.dataset.edit ?? btn.dataset.delete;
    const note = app.state.prepNotes.find((n) => n.id === id);
    if (!note) return;
    if (btn.dataset.edit !== undefined) {
      noteId.value = note.id;
      noteTitle.value = note.title;
      noteText.value = note.text;
      noteSave.textContent = 'Save note';
      updateCount();
      noteTitle.focus();
    } else {
      void app.deletePrepNote(note.id);
      if (noteId.value === note.id) resetNoteForm();
    }
  });

  let lastNotesKey = '';
  const render = (s: AppState) => {
    const parts = [s.live ? (s.paused ? 'Paused' : 'Live') : 'Idle'];
    if (s.live && s.transcriberMode) parts.push(s.transcriberMode === 'realtime' ? 'realtime captions' : 'fallback captions (3 s)');
    if (s.cueFailures >= 3) parts.push('cues degraded');
    if (s.lastError) parts.push(s.lastError);
    status.textContent = parts.join(' · ');
    keyStatus.textContent = s.hasKey ? 'Key saved on this phone.' : 'No key yet: add your OpenAI API key to get captions and cues.';
    keyStatus.className = s.hasKey ? 'ok' : 'warn';
    start.disabled = s.live;
    pause.disabled = !s.live;
    end.disabled = !s.live;
    pause.textContent = s.paused ? 'Resume' : 'Pause';
    preview.textContent = s.preview.trim() === '' ? '(blank)' : s.preview;
    captions.checked = s.prefs.captionsOn;
    cues.checked = s.prefs.cuesOn;
    popup.checked = s.prefs.autoPopup;
    if (document.activeElement !== duration) duration.value = String(Math.round(s.prefs.cueDurationMillis / 1000));
    source.value = s.audioSource;

    const notesKey = JSON.stringify(s.prepNotes);
    if (notesKey !== lastNotesKey) {
      lastNotesKey = notesKey;
      const selected = startNote.value;
      startNote.replaceChildren(option('No prep note', ''), ...s.prepNotes.map((n) => option(n.title, n.id)));
      startNote.value = s.prepNotes.some((n) => n.id === selected) ? selected : '';
      notes.replaceChildren(
        ...s.prepNotes.map((n) => {
          const li = document.createElement('li');
          const title = document.createElement('span');
          title.className = 'note-title';
          title.textContent = n.title;
          const len = document.createElement('span');
          len.className = 'hint';
          len.textContent = ` ${n.text.length} chars`;
          const edit = document.createElement('button');
          edit.type = 'button';
          edit.dataset.edit = n.id;
          edit.textContent = 'Edit';
          edit.setAttribute('aria-label', `Edit ${n.title}`);
          const del = document.createElement('button');
          del.type = 'button';
          del.dataset.delete = n.id;
          del.className = 'quiet';
          del.textContent = 'Delete';
          del.setAttribute('aria-label', `Delete ${n.title}`);
          li.append(title, len, edit, del);
          return li;
        }),
      );
    }
  };
  updateCount();
  return app.subscribe(render);
}
