# Helix App Store Screenshot Prompts

Reference style: JingNote's App Store screenshot set.

- **Canvas size:** 1290 × 2796 px (iPhone 6.9" — iPhone 17 Pro / 16 Pro Max). Apple accepts this size for the "iPhone 6.9 Display" requirement; it auto-scales to other iPhone sizes.
- **Layout:** top safe area (~120px) shows a small all-caps label in the accent color (e.g., "AI POLISH"). Below that, a 2-line headline in heavy serif/sans (~96-110pt). Below the headline, one phone mockup occupying ~55-65% of the canvas height, centered, slightly tilted is fine. Background is a soft gradient or paper texture.
- **No real screenshots inside the phone.** The phone shows a *stylized illustration* of one feature moment — clean shapes, large readable text, one clear interaction. Treat the phone interior as a designed marketing illustration, not a product screenshot.
- **Brand colors (Warm Linen theme):** background `#F7F4F0` (linen), accent `#D89B7B` (terracotta), support `#88A89E` (sage), gold `#C7A35F`, ink `#2C2825`, surface `#FFFFFF`.
- **Typography:** Fraunces (serif) for headline, Inter (sans) for label and supporting text.
- **Single phone, large.** Do not show 2-3 phones. Do not crop the device — full top + bottom visible. Phone bezel: thin, modern, color-matched to subject (dark for hero, white for some).

---

## Style preamble (prepend to every prompt)

> App Store screenshot, iPhone 6.9-inch portrait canvas, exact dimensions 1290 × 2796 pixels. Soft warm linen paper background (#F7F4F0) with subtle grain. Top zone (about 18% of canvas) holds a small all-caps eyebrow label in terracotta (#D89B7B), followed by a two-line headline in Fraunces serif at ~104pt, weight 600, color warm dark ink (#2C2825), tight tracking, slightly negative leading. Below the headline, a single iPhone 17-style device occupies the lower ~62% of the canvas, perfectly centered horizontally, with thin uniform bezel. Inside the phone, a stylized marketing illustration of the feature — large readable shapes, generous whitespace, never a literal product screenshot. Bottom 6% empty for breathing room. No multiple devices, no cropped device, no lifestyle photography, no people, no hands. No glassmorphism. No drop shadows on text. Subtle paper grain on background only. Use Inter for all small UI labels rendered inside the phone. Use Fraunces for any large headline rendered inside the phone. Composition is calm, editorial, considered — like Apple Journal or JingNote App Store screenshots.

---

## Per-screenshot prompts (5 screenshots — Apple recommends 3-10)

### Screenshot 1 — Live conversation (the hero)

**Eyebrow label:** `LIVE CONVERSATION`
**Headline:** `Hear it.\nAnswer it.`

> Inside the phone: warm linen background. Centered, two abstract human silhouettes drawn as single fluid terracotta ink lines facing each other in profile, small. Between them, a soft sage watercolor cloud with the word "Who said that?" in Inter italic 22pt. Below, a white linen card with rounded 16px corners, subtle e1 shadow, containing the AI answer in Fraunces 28pt bold ink: "Maya Angelou — 1969. From 'I Know Why the Caged Bird Sings'." Below the card, three small terracotta duotone Phosphor icons in a row: microphone, sparkle, glasses — connected by a thin sage dotted line indicating flow. Bottom of phone: soft terracotta pulse ring with a microphone glyph at center. No status bar chrome, no real iOS UI — illustration only.

---

### Screenshot 2 — Smart glasses HUD

**Eyebrow label:** `HANDS-FREE`
**Headline:** `Answers\non your face.`

> Inside the phone: top half is a black "HUD frame" rendered as if seen through smart glasses — a 2px green monospace border, with three lines of green pixel-art text inside ("MAYA ANGELOU", "I KNOW WHY THE", "CAGED BIRD SINGS — 1969") in Inter Mono 18pt, evoking the actual G1 glasses HUD. Below the HUD frame, a soft terracotta gradient connects down to a single line drawing of round wireframe smart glasses, drawn in delicate ink, taking the bottom half. Faint sage watercolor wash behind the glasses. A tiny terracotta Phosphor "lightning" duotone icon to the right of the glasses indicates real-time. Calm, technical, considered.

---

### Screenshot 3 — Interview coach mode

**Eyebrow label:** `INTERVIEW COACH`
**Headline:** `STAR-ready\nin a heartbeat.`

> Inside the phone: stack of three white linen cards, slightly fanned, each with rounded 16px corners, e1 shadow, and a small sage left-rule (4px). Card 1 (frontmost) shows: "**Situation:** Q3 churn jumped 12%." in Fraunces 24pt + Inter 18pt below. Card 2 partially visible behind: "**Task:** ..." Card 3 even further behind. Above the cards, a small terracotta Phosphor "sparkle" duotone icon and the eyebrow "SUGGESTED ANSWER" in Inter 14pt label letterspacing. Below the stack, three duotone chip icons (briefcase, chat, check) in a row with thin terracotta divider. Background inside phone: warm cream with a subtle dawn-gradient watercolor wash from terracotta into honey gold.

---

### Screenshot 4 — Background fact-check

**Eyebrow label:** `FACT-CHECK`
**Headline:** `Quietly\nverified.`

> Inside the phone: large centered watercolor circle in soft sage green, ~70% of phone width, with a single Fraunces serif quote rendered across it in warm ink: "The Eiffel Tower was built in 1889." A small terracotta duotone "check-circle" Phosphor icon sits in the bottom-right of the sage circle, with the label "VERIFIED" in Inter 12pt label-tracking below. Above the circle, three small grey-ink dots in a row — animation suggestion of "thinking quietly". Below the circle, three citation chips: "britannica.com", "wikipedia", "history.com" — each as a tiny pill in `accentTint` background with terracotta text. Generous whitespace.

---

### Screenshot 5 — Project memory

**Eyebrow label:** `LONG-TERM MEMORY`
**Headline:** `Remembers\nwhat matters.`

> Inside the phone: a loose hand-drawn knowledge constellation — 8 small circles connected by gentle curved ink lines arranged organically (not a rigid graph). Each circle is filled with a different soft watercolor wash: 4 terracotta, 2 sage, 1 honey gold, 1 cream. The largest circle is in the upper-third and contains the Fraunces text "The Q3 Memo" in 22pt bold ink. Smaller circles contain Inter labels: "Maya — PM", "deadline Fri", "concerns from legal", "Slide 7 needs revision", "follow-up Monday", "competitor: Acme". Lines between circles are dotted in places, solid in others. At the bottom of the phone, a small terracotta duotone Phosphor "brain" icon and the label "PROJECT: Q3 PLANNING" in Inter 12pt label-tracking. Cream paper background inside phone, no border chrome.

---

## Optional 6th — App icon hero (if you want a 6th slot)

**Eyebrow label:** `HELIX`
**Headline:** `A quieter edge\nfor every conversation.`

> Inside the phone: the Helix app icon — a single calligraphic helix coil drawn as continuous terracotta ink line, two strands twisting around a vertical axis, centered on a soft terracotta-to-cream watercolor sunrise wash. Phone displays only the icon at ~50% phone-width, rest is generous cream paper. Below the icon, three small Phosphor duotone icons in a tight row (microphone, sparkle, glasses) with the words "LISTEN · UNDERSTAND · ANSWER" in Inter 11pt label-tracking 0.6 below them. Calm, brand-portrait composition.

---

## Generation workflow

1. **Tool:** Recraft v3 is best for editorial line+watercolor at 1290×2796. Midjourney v7 with `--ar 1290:2796` works but may need upscaling. DALL-E 3 supports 1024×1792 max — generate then upscale 1.26× to 1290×2796 in Photoshop / Affinity / Pixelmator.
2. **Generate 4 variants per prompt**, pick best.
3. **Composite headline + label as final overlay layer** if the model renders text poorly. Most image models still mangle text at small sizes — render headline + eyebrow label as a separate text layer in your design tool over the AI-generated background and phone illustration. Use Fraunces SemiBold (600) for headline, Inter Bold for eyebrow label uppercase 0.06 tracking.
4. **Export:** PNG or JPEG (Apple accepts both), sRGB, no transparency in final.
5. **Upload to App Store Connect** under "iPhone 6.9 Display" — Apple auto-generates 6.7", 6.5", 5.5" variants by scaling.

---

## Localization note

If shipping localized listings (zh-Hans, ja, etc.), the **headline + eyebrow label** are the only translated parts — illustration content is universal. Re-export per locale with translated text composited.

## Style consistency checklist (run on each finished screenshot)

- [ ] Canvas exactly 1290 × 2796
- [ ] One phone, centered, full top + bottom visible
- [ ] Phone occupies 55-65% of canvas height
- [ ] Eyebrow label in terracotta uppercase Inter, 24-28pt, 0.06 tracking
- [ ] Headline in Fraunces SemiBold ~104pt, 2 lines, warm ink
- [ ] Background warm linen `#F7F4F0` (cream), subtle grain ok
- [ ] No glassmorphism, no neon, no 3D, no people, no hands, no real iOS chrome
- [ ] All in-phone text is legible at thumbnail size
- [ ] Color palette stays within: ink `#2C2825`, terracotta `#D89B7B`, sage `#88A89E`, gold `#C7A35F`, cream `#F7F4F0`, white `#FFFFFF`
