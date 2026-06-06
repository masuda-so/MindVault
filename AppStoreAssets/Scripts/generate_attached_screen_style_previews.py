from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "AppStoreAssets" / "ActualScreenSources"
OUT_ROOT = ROOT / "AppStoreAssets" / "AttachedScreenStylePreviews"

CANVAS_SIZE = (1284, 2778)
BACKGROUND = (218, 239, 249)
SHEET_BACKGROUND = (244, 247, 251)
INK = (47, 59, 79)

PHONE_SCREEN_W = 1040
PHONE_SCREEN_H = 2260
PHONE_SCREEN_X = (CANVAS_SIZE[0] - PHONE_SCREEN_W) // 2
PHONE_SCREEN_Y = 250
FRAME_PAD = 44
FRAME_RADIUS = 142
SCREEN_RADIUS = 106

FONT_REGULAR = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"


APPS = {
    "MindVault": [
        "01-graph",
        "02-notes",
        "03-ai-search",
        "04-note-detail-ai",
        "05-ai-proposals",
        "06-ai-export",
        "07-settings-plan",
        "08-storekit-subscription",
        "09-new-note",
        "10-markdown-editor",
    ],
    "SmallThanksDiary": [
        "01-moments",
        "02-achievements",
        "03-badge-detail",
        "04-reflection-premium",
        "05-settings",
        "06-entry-form",
        "07-moment-detail",
        "08-export-premium",
        "09-achievements-locked",
        "10-settings-premium-info",
    ],
}


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_REGULAR, size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def resize_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGB")
    src_w, src_h = image.size
    dst_w, dst_h = size
    scale = max(dst_w / src_w, dst_h / src_h)
    new_size = (round(src_w * scale), round(src_h * scale))
    resized = image.resize(new_size, Image.Resampling.LANCZOS)
    left = (new_size[0] - dst_w) // 2
    top = (new_size[1] - dst_h) // 2
    return resized.crop((left, top, left + dst_w, top + dst_h))


def draw_phone_frame(canvas: Image.Image, screen: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    frame = (
        PHONE_SCREEN_X - FRAME_PAD,
        PHONE_SCREEN_Y - FRAME_PAD,
        PHONE_SCREEN_X + PHONE_SCREEN_W + FRAME_PAD,
        PHONE_SCREEN_Y + PHONE_SCREEN_H + FRAME_PAD,
    )
    shadow = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(frame, radius=FRAME_RADIUS, fill=(0, 0, 0, 86))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.paste(shadow.convert("RGB"), (0, 0), shadow.split()[-1])

    draw.rounded_rectangle(frame, radius=FRAME_RADIUS, fill=(14, 16, 18))
    draw.rounded_rectangle(
        (
            frame[0] + 10,
            frame[1] + 10,
            frame[2] - 10,
            frame[3] - 10,
        ),
        radius=FRAME_RADIUS - 12,
        outline=(72, 74, 76),
        width=8,
    )

    # Subtle side controls keep the device recognizable without competing with the app UI.
    draw.rounded_rectangle(
        (frame[0] - 14, frame[1] + 350, frame[0] - 4, frame[1] + 520),
        radius=6,
        fill=(20, 22, 24),
    )
    draw.rounded_rectangle(
        (frame[0] - 14, frame[1] + 620, frame[0] - 4, frame[1] + 810),
        radius=6,
        fill=(20, 22, 24),
    )
    draw.rounded_rectangle(
        (frame[2] + 4, frame[1] + 520, frame[2] + 14, frame[1] + 780),
        radius=6,
        fill=(20, 22, 24),
    )

    prepared = resize_cover(screen, (PHONE_SCREEN_W, PHONE_SCREEN_H))
    mask = rounded_mask((PHONE_SCREEN_W, PHONE_SCREEN_H), SCREEN_RADIUS)
    canvas.paste(prepared, (PHONE_SCREEN_X, PHONE_SCREEN_Y), mask)


def render_preview(source_path: Path, output_stem: str, output_dir: Path) -> Path:
    source = Image.open(source_path)
    canvas = Image.new("RGB", CANVAS_SIZE, BACKGROUND)
    draw_phone_frame(canvas, source)

    png_path = output_dir / f"{output_stem}.png"
    jpg_path = output_dir / f"{output_stem}.jpg"
    canvas.save(png_path, "PNG")
    canvas.save(jpg_path, "JPEG", quality=94, optimize=True)
    return png_path


def make_contact_sheet(app_name: str, png_paths: list[Path], output_dir: Path) -> Path:
    thumb_w, thumb_h = 250, 542
    cols = 5
    rows = 2
    gap = 26
    label_h = 52
    margin = 28
    sheet_w = margin * 2 + cols * thumb_w + (cols - 1) * gap
    sheet_h = margin * 2 + rows * (thumb_h + label_h) + (rows - 1) * gap
    sheet = Image.new("RGB", (sheet_w, sheet_h), SHEET_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    label_font = font(24)

    for index, path in enumerate(png_paths):
        col = index % cols
        row = index // cols
        x = margin + col * (thumb_w + gap)
        y = margin + row * (thumb_h + label_h + gap)
        img = Image.open(path).convert("RGB")
        img.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        sheet.paste(img, (x + (thumb_w - img.width) // 2, y))
        draw.text((x + 6, y + thumb_h + 10), path.stem, fill=INK, font=label_font)

    out = output_dir / "contact-sheet.png"
    sheet.save(out, "PNG")
    print(f"{app_name}: {out}")
    return out


def generate_app(app_name: str, stems: list[str]) -> None:
    source_dir = SOURCE_ROOT / app_name / "iPhone17Pro"
    output_dir = OUT_ROOT / app_name / "iPhone65"
    output_dir.mkdir(parents=True, exist_ok=True)

    for stale in [*output_dir.glob("*.png"), *output_dir.glob("*.jpg")]:
        stale.unlink()

    png_paths: list[Path] = []
    for stem in stems:
        source_path = source_dir / f"{stem}.jpg"
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        png_paths.append(render_preview(source_path, stem, output_dir))

    make_contact_sheet(app_name, png_paths, output_dir)


def main() -> None:
    for app_name, stems in APPS.items():
        generate_app(app_name, stems)


if __name__ == "__main__":
    main()
