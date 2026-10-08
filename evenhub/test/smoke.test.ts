import { describe, expect, it } from 'vitest';
import manifest from '../app.json';

describe('scaffold', () => {
  it('manifest matches the plan constraints', () => {
    expect(manifest.package_id).toBe('com.artjiang.helixconversate');
    expect(manifest.name.length).toBeLessThanOrEqual(20);
    expect(manifest.entrypoint).toBe('index.html');
    expect(manifest.permissions.map((p) => p.name).sort()).toEqual(['g2-microphone', 'network', 'phone-microphone']);
  });

  it('0.3.0 whitelists OpenAI and the tailnet relay origin', () => {
    expect(manifest.version).toBe('0.3.0');
    const network = manifest.permissions.find((p) => p.name === 'network') as { whitelist: string[] };
    expect(network.whitelist).toEqual(['https://api.openai.com', 'wss://api.openai.com', 'https://*.ts.net']);
  });

  it('the shared contract resolves through the alias', async () => {
    const menu = (await import('@core-contract/menu.json')).default;
    expect(menu.version).toBe(2);
  });
});
