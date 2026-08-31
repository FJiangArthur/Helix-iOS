#!/usr/bin/env python3
"""Generate the Warm Linen illustration assets for the Android app.

Calls the OpenAI Images API (default model ``gpt-image-2``; ``gpt-image-1`` is
deprecated, shutdown 2026-10-23) with the prompts from the Warm Linen spec §4,
saves every raw candidate under ``android/design/generated/`` (committed source),
then post-processes the chosen candidate (``-1`` unless ``--pick`` says otherwise)
into the Android ``res/`` tree:

* illustrations → ``res/drawable-nodpi/<name>.webp`` (Pillow LANCZOS resize,
  then ``cwebp -q 85 -alpha_q 100 -m 6``; ``sips`` fallback)
* launcher icon → ``res/mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png``
  (108/162/216/324/432 px) plus a Pillow-derived ``ic_launcher_monochrome.png``

The API key is read from the ``OPENAI_API_KEY`` environment variable only. It is
never printed, logged, or written to disk.

Usage:
    export OPENAI_API_KEY=...            # in the shell, never in chat/files
    python3 scripts/generate_ui_assets.py --dry-run
    python3 scripts/generate_ui_assets.py --quality medium --candidates 2
    python3 scripts/generate_ui_assets.py --only helix_assistant_hero --quality high
    python3 scripts/generate_ui_assets.py --skip-generate --pick helix_assistant_hero=2

Exit codes: 0 ok, 1 generation/post-process failure, 2 missing API key,
3 bad arguments.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
ANDROID_DIR = PROJECT_ROOT / "android"
GENERATED_DIR = ANDROID_DIR / "design" / "generated"
RES_DIR = ANDROID_DIR / "app" / "src" / "main" / "res"
DRAWABLE_NODPI_DIR = RES_DIR / "drawable-nodpi"

API_URL = "https://api.openai.com/v1/images/generations"
DEFAULT_MODEL = "gpt-image-2"
CWEBP = Path("/opt/homebrew/bin/cwebp")

# Launcher adaptive-icon layer sizes per density bucket (108 dp layer).
MIPMAP_SIZES = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}

# Spec §4 style preamble, prepended to every prompt.
STYLE_PREAMBLE = (
    "Editorial watercolor illustration. Delicate hand-drawn ink line at ~1.5px "
    "weight in warm dark brown (#2C2825). Soft, transparent watercolor washes in "
    "terracotta (#D89B7B), sage green (#88A89E), and occasional warm gold "
    "(#C7A35F). Background is warm cream paper texture (#F7F4F0). Loose, calm, "
    "journal-like. Slightly imperfect linework — confident but human. No drop "
    "shadows. No gradients-as-effects. No glassmorphism. No neon. No 3D "
    "rendering. No hyper-realism. Centered composition, plenty of negative "
    "space. No text, no letters, no UI elements. Style references: Apple Journal "
    "app illustrations, modern editorial book covers, Tom Froese, Maggie Chiang."
)

TRANSPARENT_NOTE = (
    " Fully transparent background: no paper, no cream fill, no border — only "
    "the ink line and the watercolor washes on alpha."
)


@dataclass(frozen=True)
class Asset:
    name: str
    prompt: str
    size: str  # API size, e.g. "1024x1024" or "1536x1024"
    transparent: bool
    kind: str  # "illustration" | "icon"
    output_px: tuple[int, int]  # final width/height for drawable-nodpi (illustrations)

    @property
    def background(self) -> str:
        return "transparent" if self.transparent else "opaque"

    def full_prompt(self) -> str:
        prompt = f"{STYLE_PREAMBLE}\n\n{self.prompt}"
        if self.transparent:
            prompt += TRANSPARENT_NOTE
        return prompt


ASSETS: list[Asset] = [
    Asset(
        name="ic_launcher_foreground",
        kind="icon",
        size="1024x1024",
        transparent=True,
        output_px=(1024, 1024),
        prompt=(
            # Spec #5 — helix app icon source.
            "A single helix coil drawn as a continuous calligraphic ink line, two "
            "strands twisting around a vertical axis, centered. A soft terracotta "
            "watercolor wash glows behind it like dawn. Bold enough to read at "
            "60x60. Iconic, calm, unmistakably \"Helix.\" No text, no other "
            "elements. The whole drawing fits inside the central 55% of the "
            "canvas, leaving the outer area empty (Android adaptive icon safe zone)."
        ),
    ),
    Asset(
        name="helix_assistant_hero",
        kind="illustration",
        size="1536x1024",
        transparent=False,
        output_px=(1280, 853),
        prompt=(
            # Spec #2 — home live conversation, framed for the Assistant hero card.
            "Two abstract human silhouettes facing each other in profile, drawn as "
            "single fluid ink lines, no facial features. Between them, a small "
            "watercolor cloud in soft terracotta where their words meet, dotted "
            "with three tiny sage circles like sparks of understanding. Below "
            "them, a soft sage horizon wash. The moment of being heard. Calm, "
            "intimate, journal-like. Place the subjects in the left two-thirds of "
            "the image; the right third fades to plain cream paper with nothing on it."
        ),
    ),
    Asset(
        name="helix_empty_sessions",
        kind="illustration",
        size="1024x1024",
        transparent=True,
        output_px=(512, 512),
        prompt=(
            # Spec #9 — empty history.
            "A single open notebook page, mostly blank, drawn in loose ink line "
            "with a faint terracotta watercolor wash on one corner. Small, quiet, "
            "centered."
        ),
    ),
    Asset(
        name="helix_empty_knowledge",
        kind="illustration",
        size="1024x1024",
        transparent=True,
        output_px=(512, 512),
        prompt=(
            "A loose hand-drawn constellation of five small circles connected by "
            "gentle curved ink lines, arranged organically, not a rigid graph. "
            "Each circle filled with a soft watercolor wash — three terracotta, "
            "one sage, one warm gold. Reads as \"ideas finding each other.\""
        ),
    ),
    Asset(
        name="helix_empty_device",
        kind="illustration",
        size="1024x1024",
        transparent=True,
        output_px=(512, 512),
        prompt=(
            "A pair of round wire-frame smart glasses drawn in delicate ink line, "
            "floating gently, a soft sage watercolor wash behind one lens. A short "
            "dotted ink line drifts away from one temple, suggesting a connection "
            "waiting to be made. No face, no person."
        ),
    ),
    Asset(
        name="helix_empty_answer",
        kind="illustration",
        size="1024x1024",
        transparent=True,
        output_px=(512, 512),
        prompt=(
            "A single empty speech bubble drawn as one loose ink line, slightly "
            "imperfect, with a pale terracotta watercolor wash pooling inside it "
            "and three tiny sage dots beneath, like a thought about to arrive."
        ),
    ),
    Asset(
        name="helix_device_hero",
        kind="illustration",
        size="1024x1024",
        transparent=False,
        output_px=(1024, 1024),
        prompt=(
            # Spec #3 — glasses device hero (optional).
            "A single pair of round smart glasses laid flat on warm cream paper, "
            "drawn three-quarter overhead view in delicate ink line. Soft "
            "terracotta watercolor pooling around the left lens like ink bleeding "
            "into paper. A faint sage shadow beneath suggests gentle weight. No "
            "background scenery. Object-as-portrait, considered and crafted, like "
            "a still life from a notebook."
        ),
    ),
]

ASSETS_BY_NAME = {asset.name: asset for asset in ASSETS}


# --------------------------------------------------------------------------- #
# API
# --------------------------------------------------------------------------- #


def build_payload(asset: Asset, model: str, quality: str) -> dict:
    return {
        "model": model,
        "prompt": asset.full_prompt(),
        "n": 1,
        "size": asset.size,
        "quality": quality,
        "background": asset.background,
        "output_format": "png",
    }


def call_images_api(payload: dict, api_key: str, retries: int = 3) -> bytes:
    body = json.dumps(payload).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        request = urllib.request.Request(API_URL, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                result = json.loads(response.read().decode("utf-8"))
            data = result.get("data") or []
            if not data or "b64_json" not in data[0]:
                raise RuntimeError(f"unexpected response shape: {list(result.keys())}")
            return base64.b64decode(data[0]["b64_json"])
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")[:600]
            # 4xx other than 429 will not improve on retry.
            if 400 <= error.code < 500 and error.code != 429:
                raise RuntimeError(f"HTTP {error.code}: {detail}") from None
            last_error = RuntimeError(f"HTTP {error.code}: {detail}")
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
        wait = 5 * attempt
        print(f"    attempt {attempt} failed ({last_error}); retrying in {wait}s", file=sys.stderr)
        time.sleep(wait)
    raise RuntimeError(f"giving up after {retries} attempts: {last_error}")


# --------------------------------------------------------------------------- #
# Post-processing
# --------------------------------------------------------------------------- #


def require_pillow():
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        sys.exit("Pillow is required for post-processing: python3 -m pip install pillow")


def encode_webp(png_path: Path, webp_path: Path) -> None:
    webp_path.parent.mkdir(parents=True, exist_ok=True)
    if CWEBP.exists():
        subprocess.run(
            [str(CWEBP), "-quiet", "-q", "85", "-alpha_q", "100", "-m", "6",
             str(png_path), "-o", str(webp_path)],
            check=True,
        )
        return
    if shutil.which("sips"):
        subprocess.run(
            ["sips", "-s", "format", "webp", "-s", "formatOptions", "85",
             str(png_path), "--out", str(webp_path)],
            check=True,
            capture_output=True,
        )
        return
    # Last resort: Pillow's own encoder.
    from PIL import Image

    with Image.open(png_path) as image:
        image.save(webp_path, "WEBP", quality=85, method=6)


def postprocess_illustration(asset: Asset, raw_png: Path) -> list[Path]:
    from PIL import Image

    width, height = asset.output_px
    tmp_png = GENERATED_DIR / f"{asset.name}-resized.png"
    with Image.open(raw_png) as image:
        mode = "RGBA" if asset.transparent else "RGB"
        resized = image.convert(mode).resize((width, height), Image.LANCZOS)
        resized.save(tmp_png, "PNG", optimize=True)
    out = DRAWABLE_NODPI_DIR / f"{asset.name}.webp"
    encode_webp(tmp_png, out)
    tmp_png.unlink(missing_ok=True)
    return [out]


def postprocess_icon(asset: Asset, raw_png: Path) -> list[Path]:
    from PIL import Image, ImageChops, ImageOps

    outputs: list[Path] = []
    with Image.open(raw_png) as image:
        rgba = image.convert("RGBA")
        # Monochrome layer (Android themed icons): a solid black glyph whose
        # alpha is alpha * (1 - luminance), so dark ink stays opaque and the
        # pale watercolor washes fade out.
        inverted = ImageOps.invert(rgba.convert("L"))
        mono_alpha = ImageChops.multiply(inverted, rgba.getchannel("A"))
        monochrome = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
        monochrome.putalpha(mono_alpha)

        for bucket, px in MIPMAP_SIZES.items():
            directory = RES_DIR / f"mipmap-{bucket}"
            directory.mkdir(parents=True, exist_ok=True)
            fg_path = directory / "ic_launcher_foreground.png"
            rgba.resize((px, px), Image.LANCZOS).save(fg_path, "PNG", optimize=True)
            outputs.append(fg_path)
            mono_path = directory / "ic_launcher_monochrome.png"
            monochrome.resize((px, px), Image.LANCZOS).save(mono_path, "PNG", optimize=True)
            outputs.append(mono_path)
    return outputs


def postprocess(asset: Asset, raw_png: Path) -> list[Path]:
    if asset.kind == "icon":
        return postprocess_icon(asset, raw_png)
    return postprocess_illustration(asset, raw_png)


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", action="append", metavar="NAME",
                        help="generate only this asset (repeatable); default all")
    parser.add_argument("--candidates", type=int, default=2, metavar="N",
                        help="candidates per asset (default 2)")
    parser.add_argument("--quality", choices=["low", "medium", "high"], default="medium")
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help=f"image model (default {DEFAULT_MODEL})")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the exact request payloads and output paths; no network")
    parser.add_argument("--skip-generate", action="store_true",
                        help="skip the API and post-process existing candidates only")
    parser.add_argument("--pick", action="append", default=[], metavar="NAME=K",
                        help="candidate index to post-process for NAME (default 1)")
    parser.add_argument("--list", action="store_true", help="list asset names and exit")
    return parser.parse_args(argv)


def parse_picks(raw: list[str]) -> dict[str, int]:
    picks: dict[str, int] = {}
    for item in raw:
        if "=" not in item:
            sys.exit(f"--pick expects NAME=K, got {item!r}")
        name, _, index = item.partition("=")
        if name not in ASSETS_BY_NAME:
            sys.exit(f"--pick: unknown asset {name!r}")
        try:
            picks[name] = int(index)
        except ValueError:
            sys.exit(f"--pick: K must be an integer in {item!r}")
    return picks


def candidate_path(asset: Asset, k: int) -> Path:
    return GENERATED_DIR / f"{asset.name}-{k}.png"


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    if args.list:
        for asset in ASSETS:
            print(f"{asset.name:28} {asset.kind:12} {asset.size:9} {asset.background}")
        return 0

    if args.candidates < 1:
        print("--candidates must be >= 1", file=sys.stderr)
        return 3
    selected = ASSETS
    if args.only:
        unknown = [name for name in args.only if name not in ASSETS_BY_NAME]
        if unknown:
            print(f"unknown asset(s): {', '.join(unknown)}; use --list", file=sys.stderr)
            return 3
        selected = [ASSETS_BY_NAME[name] for name in args.only]
    picks = parse_picks(args.pick)

    if args.dry_run:
        print(f"# dry run — model={args.model} quality={args.quality} candidates={args.candidates}")
        print(f"# POST {API_URL}")
        print(f"# raw candidates -> {GENERATED_DIR}")
        for asset in selected:
            payload = build_payload(asset, args.model, args.quality)
            print(f"\n## {asset.name} ({asset.kind})")
            for k in range(1, args.candidates + 1):
                print(f"#   candidate {k} -> {candidate_path(asset, k)}")
            if asset.kind == "icon":
                for bucket, px in MIPMAP_SIZES.items():
                    print(f"#   {RES_DIR / f'mipmap-{bucket}'}/ic_launcher_{{foreground,monochrome}}.png ({px}px)")
            else:
                print(f"#   {DRAWABLE_NODPI_DIR / (asset.name + '.webp')} ({asset.output_px[0]}x{asset.output_px[1]})")
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    api_key = None
    if not args.skip_generate:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            print("OPENAI_API_KEY is not set; export it in the shell (never paste it in chat).",
                  file=sys.stderr)
            return 2

    require_pillow()
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    failures = 0

    # Model fallback chain: a project whose allowlist lacks the requested
    # model returns 403 model_not_found; degrade to the older image models
    # (gpt-image-1 is available until 2026-10-23) instead of failing outright.
    model = args.model
    fallback_models = [m for m in ("gpt-image-1", "gpt-image-1-mini") if m != model]

    for asset in selected:
        print(f"== {asset.name}")
        if not args.skip_generate:
            payload = build_payload(asset, model, args.quality)
            for k in range(1, args.candidates + 1):
                out = candidate_path(asset, k)
                print(f"   generating candidate {k}/{args.candidates} ({asset.size}, {asset.background})")
                try:
                    png = call_images_api(payload, api_key)
                except RuntimeError as error:
                    if "model_not_found" in str(error) and fallback_models:
                        model = fallback_models.pop(0)
                        print(
                            f"   model not available to this project; falling back to {model}",
                            file=sys.stderr,
                        )
                        payload = build_payload(asset, model, args.quality)
                        try:
                            png = call_images_api(payload, api_key)
                        except RuntimeError as retry_error:
                            print(f"   FAILED: {retry_error}", file=sys.stderr)
                            failures += 1
                            continue
                    else:
                        print(f"   FAILED: {error}", file=sys.stderr)
                        failures += 1
                        continue
                out.write_bytes(png)
                print(f"   saved {out} ({len(png)} bytes)")

        chosen = candidate_path(asset, picks.get(asset.name, 1))
        if not chosen.exists():
            print(f"   no candidate at {chosen}; skipping post-process", file=sys.stderr)
            failures += 1
            continue
        try:
            outputs = postprocess(asset, chosen)
        except (OSError, subprocess.CalledProcessError) as error:
            print(f"   post-process FAILED: {error}", file=sys.stderr)
            failures += 1
            continue
        for path in outputs:
            print(f"   wrote {path} ({path.stat().st_size} bytes)")

    if failures:
        print(f"{failures} step(s) failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
