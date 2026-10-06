// Shared cue-extraction prompt (conversate-core/prompts/cues.v1.json).
// Port of Android CuePrompt (MenuSpec.kt).
import promptJson from '@core-contract/prompts/cues.v1.json';

export interface CuePrompt {
  version: number;
  maxTokens: number;
  template: string;
  render(transcript: string, prepNote: string, shown: string[]): string;
}

export function loadCuePrompt(): CuePrompt {
  const { version, maxTokens, template } = promptJson as { version: number; maxTokens: number; template: string };
  return {
    version,
    maxTokens,
    template,
    render(transcript, prepNote, shown) {
      // split/join, not replace(): a transcript containing `$&` must stay literal.
      return template
        .split('{{shown}}').join(shown.length === 0 ? '(none)' : shown.join(', '))
        .split('{{prep_note}}').join(prepNote.trim() === '' ? '(none)' : prepNote)
        .split('{{transcript}}').join(transcript);
    },
  };
}
