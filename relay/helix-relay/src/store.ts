import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import type { Dashboard, NewsItem, OmiItem, TodoItem, XItem } from './types.js';

export interface Snapshot extends Dashboard {
  /** LLM-extracted due times for to-dos Omi has no due_at for (todo id → ISO). */
  dueAtOverrides: Record<string, string>;
}

export function emptySnapshot(): Snapshot {
  return {
    generatedAt: new Date(0).toISOString(),
    briefing: [],
    news: [],
    x: [],
    todos: [],
    omi: [],
    dueAtOverrides: {},
  };
}

const arr = <T>(v: unknown): T[] => (Array.isArray(v) ? (v as T[]) : []);

/** In-memory cache of the last refresh, optionally persisted to `<dataDir>/cache.json`. */
export class Store {
  private snap: Snapshot = emptySnapshot();
  constructor(private readonly file: string | null) {}

  static forDataDir(dataDir: string): Store {
    return new Store(path.join(dataDir, 'cache.json'));
  }

  get(): Snapshot {
    return this.snap;
  }

  set(next: Snapshot): void {
    this.snap = next;
  }

  dashboard(): Dashboard {
    const { generatedAt, briefing, news, x, todos, omi } = this.snap;
    return { generatedAt, briefing, news, x, todos, omi };
  }

  updateTodo(todo: TodoItem): void {
    const todos = this.snap.todos.some((t) => t.id === todo.id)
      ? this.snap.todos.map((t) => (t.id === todo.id ? todo : t))
      : [...this.snap.todos, todo];
    this.snap = { ...this.snap, todos };
  }

  async load(): Promise<void> {
    if (!this.file) return;
    try {
      const raw = JSON.parse(await readFile(this.file, 'utf8')) as Partial<Snapshot>;
      this.snap = {
        generatedAt: typeof raw.generatedAt === 'string' ? raw.generatedAt : emptySnapshot().generatedAt,
        briefing: arr<string>(raw.briefing).filter((s) => typeof s === 'string'),
        news: arr<NewsItem>(raw.news),
        x: arr<XItem>(raw.x),
        todos: arr<TodoItem>(raw.todos),
        omi: arr<OmiItem>(raw.omi),
        dueAtOverrides:
          raw.dueAtOverrides && typeof raw.dueAtOverrides === 'object' ? raw.dueAtOverrides : {},
      };
    } catch {
      // Missing or corrupt cache: start empty; the first refresh repopulates it.
    }
  }

  async save(): Promise<void> {
    if (!this.file) return;
    await mkdir(path.dirname(this.file), { recursive: true, mode: 0o700 });
    const tmp = `${this.file}.tmp`;
    await writeFile(tmp, JSON.stringify(this.snap, null, 2), { mode: 0o600 });
    await rename(tmp, this.file);
  }
}
