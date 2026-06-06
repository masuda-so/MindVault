from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT_ROOT = ROOT / "AppStoreAssets" / "MynaportalStylePreviews"

W, H = 1284, 2778
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_MEDIUM = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"

MINDVAULT_ICON = ROOT / "MindVault" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-iOS-Default-1024x1024@1x.png"
MINDVAULT_SOURCE = ROOT / "AppStoreAssets" / "Screenshots" / "iPhone65"

GRATEFUL_ROOT = Path("/Users/masudaso/Desktop/GratefulMoments")
GRATEFUL_ICON = GRATEFUL_ROOT / "GratefulMoments" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon1024x1024.png"
GRATEFUL_SOURCE = GRATEFUL_ROOT / "AppStoreConnectAssets"

TEXT = (10, 18, 28)
MUTED = (92, 103, 116)
HAIRLINE = (222, 227, 233)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def measure(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0], box[3] - box[1]


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, img.size[0], img.size[1]), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def wrap_ja(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    lines = []
    current = ""
    for char in text:
        candidate = current + char
        if current and measure(draw, candidate, fnt)[0] > max_width:
            lines.append(current)
            current = char
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def draw_label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, color: tuple[int, int, int]) -> None:
    fnt = font(FONT_MEDIUM, 28)
    x, y = xy
    tw, _ = measure(draw, text, fnt)
    draw.rounded_rectangle((x, y, x + tw + 38, y + 46), radius=23, fill=(247, 249, 251), outline=HAIRLINE, width=2)
    draw.text((x + 19, y + 8), text, font=fnt, fill=color)


def draw_header(base: Image.Image, slide: dict, index: int, icon_path: Path) -> None:
    draw = ImageDraw.Draw(base)
    margin = 90
    accent = slide["accent"]

    icon_size = 92
    icon = Image.open(icon_path).convert("RGB").resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    icon_img = rounded(icon, 22)
    base.paste(icon_img, (W - margin - icon_size, 84), icon_img)

    draw_label(draw, (margin, 86), f"{index:02d} {slide['app']}", accent)

    title_font = font(FONT_BOLD, 72)
    title_lines = slide.get("title_lines") or wrap_ja(draw, slide["title"], title_font, 940)
    y = 188
    for line in title_lines[:2]:
        draw.text((margin, y), line, font=title_font, fill=TEXT)
        y += 88

    body_font = font(FONT_REGULAR, 34)
    body_lines = wrap_ja(draw, slide["body"], body_font, 980)
    y += 18
    for line in body_lines[:2]:
        draw.text((margin, y), line, font=body_font, fill=MUTED)
        y += 46

    draw.rounded_rectangle((margin, 500, margin + 120, 510), radius=5, fill=accent)


def paste_phone(base: Image.Image, source_path: Path, top: int, crop_top: int = 0) -> None:
    source = Image.open(source_path).convert("RGB")
    if crop_top:
        source = source.crop((0, crop_top, source.width, source.height))

    frame_w = 1010
    screen_w = 938
    screen_h = round(source.height * screen_w / source.width)
    source = source.resize((screen_w, screen_h), Image.Resampling.LANCZOS)

    frame_h = min(2130, screen_h + 86)
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle((0, 0, frame_w, frame_h), radius=124, fill=(10, 12, 16))
    frame_draw.rounded_rectangle((23, 23, frame_w - 23, frame_h - 23), radius=104, fill=(255, 255, 255))

    screen = source.crop((0, 0, screen_w, min(screen_h, frame_h - 78)))
    screen_img = rounded(screen, 86)
    frame.paste(screen_img, (36, 36), screen_img)

    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    mask = Image.new("L", frame.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, frame_w, frame_h), radius=124, fill=32)
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(22)))

    x = (W - frame_w) // 2
    base.paste(shadow, (x, top + 22), shadow)
    base.paste(frame, (x, top), frame)


def draw_lower_note(base: Image.Image, slide: dict) -> None:
    return


def create_slide(slide: dict, index: int, out_dir: Path, icon_path: Path) -> Path:
    base = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    draw = ImageDraw.Draw(base)
    draw.rectangle((0, 558, W, 559), fill=HAIRLINE)
    draw_header(base, slide, index, icon_path)
    paste_phone(base, slide["source"], top=628, crop_top=slide.get("crop_top", 0))
    draw_lower_note(base, slide)

    out_dir.mkdir(parents=True, exist_ok=True)
    png_path = out_dir / slide["out"]
    jpg_path = out_dir / slide["out"].replace(".png", ".jpg")
    base.convert("RGB").save(png_path, "PNG", optimize=True)
    base.convert("RGB").save(jpg_path, "JPEG", quality=95, optimize=True)
    return png_path


def contact_sheet(paths: list[Path], out_path: Path) -> None:
    thumbs = []
    for path in paths:
        img = Image.open(path).convert("RGB")
        thumb_w = 300
        thumb_h = round(img.height * thumb_w / img.width)
        thumbs.append(img.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS))

    pad = 28
    sheet = Image.new("RGB", (pad * 5 + 300 * 4, max(t.height for t in thumbs) + pad * 2), (242, 244, 247))
    for idx, thumb in enumerate(thumbs):
        sheet.paste(thumb, (pad + idx * (300 + pad), pad))
    sheet.save(out_path, "PNG", optimize=True)


def main() -> None:
    mindvault_slides = [
        {
            "app": "MindVault",
            "title": "知識グラフで、メモを確認",
            "title_lines": ["知識グラフで、", "メモを確認"],
            "body": "起動するとすぐ、保存したメモのつながりを一覧できます。",
            "footer": "グラフ表示",
            "source": MINDVAULT_SOURCE / "01-graph.png",
            "out": "01-graph.png",
            "accent": (0, 120, 116),
            "note_title": "表示されるもの",
            "note": "メモ、リンク、タグ、AI提案を1つの画面で確認できます。",
        },
        {
            "app": "MindVault",
            "title": "Markdownメモを作成",
            "title_lines": ["Markdownメモを", "作成"],
            "body": "日々のメモをMarkdownで保存し、リンクで整理できます。",
            "footer": "メモ作成",
            "source": MINDVAULT_SOURCE / "02-notes.png",
            "out": "02-notes.png",
            "accent": (0, 104, 210),
            "note_title": "対応する整理",
            "note": "タグ、日付、wiki linkで必要なメモへ戻りやすくします。",
        },
        {
            "app": "MindVault",
            "title": "ローカルノートを検索",
            "title_lines": ["ローカルノートを", "検索"],
            "body": "端末内のメモから関連候補を探し、すばやく参照できます。",
            "footer": "検索",
            "source": MINDVAULT_SOURCE / "03-search.png",
            "out": "03-search.png",
            "accent": (0, 104, 210),
            "note_title": "AI対応端末では",
            "note": "Apple Foundation Modelsによる整理候補も利用できます。",
        },
        {
            "app": "MindVault",
            "title": "ローカル優先で管理",
            "title_lines": ["ローカル優先で", "管理"],
            "body": "メモ本文を外部AIや独自サーバーへ送らずに利用できます。",
            "footer": "プライバシー",
            "source": MINDVAULT_SOURCE / "04-settings-plan.png",
            "out": "04-privacy.png",
            "accent": (94, 85, 205),
            "note_title": "安心して使うために",
            "note": "プライバシー設定とプラン情報をアプリ内で確認できます。",
        },
    ]

    grateful_slides = [
        {
            "app": "小さなありがとう日記",
            "title": "ありがとうを写真で記録",
            "title_lines": ["ありがとうを", "写真で記録"],
            "body": "毎日の小さな感謝を、写真とメモで残せます。",
            "footer": "日記",
            "source": GRATEFUL_SOURCE / "SourceScreensSample" / "01-Moments.png",
            "out": "01-moments.png",
            "accent": (245, 113, 0),
            "note_title": "記録できるもの",
            "note": "タイトル、メモ、写真をまとめて端末内に保存します。",
        },
        {
            "app": "小さなありがとう日記",
            "title": "続けた記録を確認",
            "title_lines": ["続けた記録を", "確認"],
            "body": "連続記録とバッジで、日々のふりかえりを続けやすくします。",
            "footer": "達成",
            "source": GRATEFUL_SOURCE / "SourceScreensSample" / "02-Achievements.png",
            "out": "02-achievements.png",
            "accent": (218, 73, 90),
            "note_title": "習慣化を支える表示",
            "note": "日数、獲得バッジ、未獲得バッジを確認できます。",
        },
        {
            "app": "小さなありがとう日記",
            "title": "その場ですぐ保存",
            "title_lines": ["その場で", "すぐ保存"],
            "body": "うれしかったことを、気持ちが新しいうちに入力できます。",
            "footer": "入力",
            "source": GRATEFUL_SOURCE / "SourceScreens" / "03-Create.png",
            "out": "03-entry.png",
            "accent": (245, 113, 0),
            "note_title": "入力はシンプル",
            "note": "タイトル、本文、写真を選び、保存するだけです。",
        },
        {
            "app": "小さなありがとう日記",
            "title": "Premiumで長く使う",
            "title_lines": ["Premiumで", "長く使う"],
            "body": "記録数の制限解除、書き出し、ふりかえり機能を利用できます。",
            "footer": "Premium",
            "source": GRATEFUL_SOURCE / "IAPReviewScreenshot-PremiumMonthly.png",
            "out": "04-premium.png",
            "accent": (7, 119, 132),
            "note_title": "Premiumの内容",
            "note": "無制限記録、PDF/CSV書き出し、対応端末でのふりかえり。",
        },
    ]

    created: list[Path] = []
    mindvault_out = OUT_ROOT / "MindVault" / "iPhone65"
    grateful_out = OUT_ROOT / "SmallThanksDiary" / "iPhone65"

    for index, slide in enumerate(mindvault_slides, start=1):
        created.append(create_slide(slide, index, mindvault_out, MINDVAULT_ICON))
    contact_sheet(created[-4:], mindvault_out / "contact-sheet.png")

    for index, slide in enumerate(grateful_slides, start=1):
        created.append(create_slide(slide, index, grateful_out, GRATEFUL_ICON))
    contact_sheet(created[-4:], grateful_out / "contact-sheet.png")

    (OUT_ROOT / "README.md").write_text(
        "\n".join(
            [
                "# Mynaportal Style App Store Previews",
                "",
                "Practical App Store preview candidates modeled after the Mynaportal direction: plain white canvas, minimal decoration, large straight phone mockup, short Japanese functional headline, restrained brand accent, and clear explanatory note.",
                "",
                "- MindVault: `MindVault/iPhone65/`",
                "- 小さなありがとう日記: `SmallThanksDiary/iPhone65/`",
                "- 今日のひとコマ: excluded; user indicated it is superseded by 小さなありがとう日記 and should be deleted later.",
                "",
                "Review locally before replacing App Store Connect screenshots.",
            ]
        ),
        encoding="utf-8",
    )

    for path in created:
        print(path)
    print(mindvault_out / "contact-sheet.png")
    print(grateful_out / "contact-sheet.png")


if __name__ == "__main__":
    main()
