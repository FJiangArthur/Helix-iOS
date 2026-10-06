// Live caption text: committed finals plus the current partial, word-wrapped
// to lens lines (spec §5.3). Port of Android CaptionBuffer.kt with the wrap
// function injected (G2 line width differs from G1's HudPaginator).

export interface TranscriptSegment {
  text: string;
  isFinal: boolean;
}

/** Greedy word wrap at [width] characters; words longer than a line are hard-split. */
export function wrapText(text: string, width: number): string[] {
  const words = text.trim().split(/\s+/).filter((w) => w !== '');
  const lines: string[] = [];
  let line = '';
  for (let word of words) {
    while (word.length > width) {
      if (line !== '') { lines.push(line); line = ''; }
      lines.push(word.slice(0, width));
      word = word.slice(width);
    }
    if (word === '') continue;
    if (line === '') line = word;
    else if (line.length + 1 + word.length <= width) line += ' ' + word;
    else { lines.push(line); line = word; }
  }
  if (line !== '') lines.push(line);
  return lines;
}

export class CaptionBuffer {
  private finals: string[] = [];
  private partial = '';

  constructor(
    private readonly wrap: (text: string) => string[],
    private readonly maxLines = 5,
    private readonly keepFinals = 12,
  ) {}

  onSegment(segment: TranscriptSegment): void {
    const text = segment.text.trim();
    if (segment.isFinal) {
      if (text !== '') this.finals.push(text);
      while (this.finals.length > this.keepFinals) this.finals.shift();
      this.partial = '';
    } else {
      this.partial = text;
    }
  }

  lines(): string[] {
    const joined = [...this.finals, this.partial].filter((t) => t.trim() !== '').join(' ');
    if (joined.trim() === '') return [];
    return this.wrap(joined).slice(-this.maxLines);
  }

  clear(): void {
    this.finals = [];
    this.partial = '';
  }
}
