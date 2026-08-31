// Omi → Helix live-transcript relay (Cloudflare Worker + Durable Object).
//
// Omi's app POSTs transcript segments to a webhook URL as a conversation
// unfolds. A phone can't be a public endpoint, so this Worker receives them
// and lets the Helix app long-poll for anything new.
//
//   Omi  → POST /hook/<token>/transcript?session_id=..&uid=..   (JSON array)
//   Omi  → POST /hook/<token>/audio                              (ignored, 200)
//   Helix→ GET  /feed/<token>?after=<seq>&wait=<seconds>         (long-poll)
//
// <token> is a secret you choose (>= 16 chars); it is the only auth. One
// Durable Object per token keeps an ordered, de-duplicated ring buffer.

const MIN_TOKEN_LENGTH = 16;
const MAX_WAIT_SECONDS = 25;
const BUFFER_LIMIT = 500;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean);

    if (parts.length === 0) {
      return json({ ok: true, service: "omi-helix-relay" });
    }

    const [kind, token, sub] = parts;
    if ((kind !== "hook" && kind !== "feed") || !token || token.length < MIN_TOKEN_LENGTH) {
      return json({ error: "not found" }, 404);
    }

    const stub = env.STREAM.get(env.STREAM.idFromName(token));

    if (kind === "hook") {
      if (request.method !== "POST") return json({ error: "method" }, 405);
      if (sub === "audio") return new Response("", { status: 200 }); // not used by Helix
      if (sub !== "transcript") return json({ error: "not found" }, 404);
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ error: "invalid json" }, 400);
      }
      const segments = Array.isArray(body) ? body : Array.isArray(body?.segments) ? body.segments : [];
      // Respond fast regardless of buffer work — Omi times out slow hooks.
      const payload = {
        session_id: url.searchParams.get("session_id") || "",
        uid: url.searchParams.get("uid") || "",
        segments,
      };
      await stub.fetch("https://do/append", { method: "POST", body: JSON.stringify(payload) });
      return json({ ok: true, received: segments.length });
    }

    // kind === "feed"
    if (request.method !== "GET") return json({ error: "method" }, 405);
    const after = Number(url.searchParams.get("after") || 0);
    const wait = Math.min(Number(url.searchParams.get("wait") || 0), MAX_WAIT_SECONDS);
    return stub.fetch(`https://do/feed?after=${after}&wait=${wait}`);
  },
};

export class OmiStream {
  constructor(state) {
    this.state = state;
    this.segments = null; // [{seq, ...}]
    this.seq = 0;
    this.waiters = [];
  }

  async load() {
    if (this.segments !== null) return;
    const stored = (await this.state.storage.get("segments")) || [];
    this.segments = stored;
    this.seq = stored.length ? stored[stored.length - 1].seq : 0;
  }

  async fetch(request) {
    await this.load();
    const url = new URL(request.url);

    if (url.pathname === "/append") {
      const { session_id, uid, segments } = await request.json();
      const added = this.append(session_id, uid, segments);
      if (added > 0) {
        await this.state.storage.put("segments", this.segments);
        const waiters = this.waiters;
        this.waiters = [];
        for (const resolve of waiters) resolve();
      }
      return json({ ok: true, added });
    }

    if (url.pathname === "/feed") {
      const after = Number(url.searchParams.get("after") || 0);
      const wait = Number(url.searchParams.get("wait") || 0);
      let fresh = this.segments.filter((s) => s.seq > after);
      if (fresh.length === 0 && wait > 0) {
        await new Promise((resolve) => {
          this.waiters.push(resolve);
          setTimeout(() => {
            // Timed out with no speech: drop ourselves so an idle session
            // can't grow the waiter list unboundedly between appends.
            this.waiters = this.waiters.filter((w) => w !== resolve);
            resolve();
          }, wait * 1000);
        });
        fresh = this.segments.filter((s) => s.seq > after);
      }
      return json({ seq: this.seq, segments: fresh });
    }

    return json({ error: "not found" }, 404);
  }

  append(sessionId, uid, incoming) {
    let added = 0;
    for (const raw of incoming) {
      const text = typeof raw?.text === "string" ? raw.text.trim() : "";
      if (!text) continue;
      const key = `${sessionId}|${raw.start ?? ""}|${text}`;
      // Omi may re-send a segment across calls; drop exact repeats.
      if (this.segments.some((s) => s.key === key)) continue;
      this.seq += 1;
      this.segments.push({
        seq: this.seq,
        key,
        session_id: sessionId,
        uid,
        text,
        speaker: raw.speaker ?? null,
        speaker_id: raw.speakerId ?? raw.speaker_id ?? null,
        is_user: Boolean(raw.is_user),
        start: raw.start ?? null,
        end: raw.end ?? null,
        received_at: Date.now(),
      });
      added += 1;
    }
    if (this.segments.length > BUFFER_LIMIT) {
      this.segments = this.segments.slice(this.segments.length - BUFFER_LIMIT);
    }
    return added;
  }
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
