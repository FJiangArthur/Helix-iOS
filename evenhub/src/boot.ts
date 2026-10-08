// Startup sequence, separate from main.ts so tests can drive it. The phone UI
// and the visibility re-arm never depend on the relay or on init succeeding
// (conversate-core/CONTRACT-0.3.md §8: the UI renders first).
import type { App } from './app';
import { mountPhoneUi } from './phone/ui';

export async function startApp(root: HTMLElement, app: App, doc: Document = document): Promise<void> {
  try {
    await app.init();
  } catch (e) {
    console.error('[helix] init failed', e);
  }
  mountPhoneUi(root, app);
  // Android may suspend the WebView in the background: re-arm on return.
  doc.addEventListener('visibilitychange', () => {
    if (doc.visibilityState === 'visible') void app.resume();
  });
}
