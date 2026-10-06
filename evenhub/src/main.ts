// Entry point. Inside the Even app WebView the SDK bridge drives the glasses;
// in a plain browser (dev, tests of the phone page) the app runs without a
// bridge and stores settings in localStorage.
import { waitForEvenAppBridge } from '@evenrealities/even_hub_sdk';
import { App, type HubBridge } from './app';
import { mountPhoneUi } from './phone/ui';
import { browserStore, bridgeStore, type KeyValueStore } from './storage';

const BRIDGE_WAIT_MILLIS = 2_000;

function hostAvailable(): boolean {
  const w = window as unknown as { flutter_inappwebview?: { callHandler?: unknown } };
  return typeof w.flutter_inappwebview?.callHandler === 'function';
}

async function connect(): Promise<{ bridge: HubBridge | null; store: KeyValueStore }> {
  const timeout = new Promise<null>((r) => setTimeout(() => r(null), BRIDGE_WAIT_MILLIS));
  const bridge = await Promise.race([waitForEvenAppBridge(), timeout]);
  if (bridge && hostAvailable()) return { bridge, store: bridgeStore(bridge) };
  return { bridge: null, store: browserStore() };
}

async function boot(): Promise<void> {
  const root = document.getElementById('app');
  if (!root) return;
  const { bridge, store } = await connect();
  const app = new App({ bridge, store });
  await app.init();
  mountPhoneUi(root, app);
  if (!bridge) console.info('[helix] no Even app bridge: running phone page only');
}

void boot();
