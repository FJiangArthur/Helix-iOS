// Wire shapes — normative source: conversate-core/CONTRACT-0.3.md §7 and
// conversate-core/fixtures/relay-{dashboard,reminders}.json.

export interface NewsItem {
  id: string;
  title: string;
  detail: string;
  source: string;
  url: string;
  publishedAt: string;
}

export interface XItem {
  id: string;
  title: string;
  detail: string;
  url: string;
}

export interface TodoItem {
  id: string;
  title: string;
  detail: string;
  completed: boolean;
  dueAt: string | null;
}

export interface OmiItem {
  id: string;
  title: string;
  detail: string;
  createdAt: string;
}

export interface Dashboard {
  generatedAt: string;
  briefing: string[];
  news: NewsItem[];
  x: XItem[];
  todos: TodoItem[];
  omi: OmiItem[];
}

export interface Reminder {
  id: string;
  kind: 'todo' | 'briefing';
  text: string;
  dueAt: string | null;
}

/** Raw Omi developer-API action item (GET/PATCH /v1/dev/user/action-items). */
export interface OmiActionItem {
  id: string;
  description: string;
  completed: boolean;
  created_at?: string | null;
  updated_at?: string | null;
  due_at?: string | null;
  completed_at?: string | null;
  conversation_id?: string | null;
}

/** Raw Omi developer-API memory (GET /v1/dev/user/memories). */
export interface OmiMemory {
  id: string;
  content: string;
  category?: string;
  created_at?: string | null;
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export type StreamChat = (
  req: { model: string; messages: ChatMessage[] },
  signal: AbortSignal,
) => AsyncIterable<string>;

export type PatchTodo = (id: string, completed: boolean) => Promise<OmiActionItem>;
