from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT_ROOT = ROOT / "AppStoreAssets" / "DigitalAgencyStylePreviews"

W, H = 1284, 2778
FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_MEDIUM = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"

MINDVAULT_ICON = ROOT / "MindVault" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-iOS-Default-1024x1024@1x.png"
MINDVAULT_SOURCE = ROOT / "AppStoreAssets" / "Screenshots" / "iPhone65"

GRATEFUL_ROOT = Path("/Users/masudaso/Desktop/GratefulMoments")
GRATEFUL_ICON = GRATEFUL_ROOT / "GratefulMoments" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon1024x1024.png"
GRATEFUL_SOURCE = GRATEFUL_ROOT / "AppStoreConnectAssets"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def measure(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0], box[3] - box[1]


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


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, img.size[0], img.size[1]), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def paste_shadowed(base: Image.Image, img: Image.Image, xy: tuple[int, int], radius: int, alpha: int = 44) -> None:
    x, y = xy
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    mask = Image.new("L", img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, img.size[0], img.size[1]), radius=radius, fill=alpha)
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(24)))
    base.paste(shadow, (x, y + 22), shadow)
    base.paste(img, (x, y), img)


def soft_circle(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, color: tuple[int, int, int], width: int = 8) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), outline=color, width=width)


def draw_hexagon(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, color: tuple[int, int, int], width: int) -> None:
    import math

    x, y = center
    points = []
    for i in range(6):
        angle = math.pi / 6 + i * math.pi / 3
        points.append((x + math.cos(angle) * radius, y + math.sin(angle) * radius))
    draw.line(points + [points[0]], fill=color, width=width, joint="curve")


def draw_header(base: Image.Image, slide: dict, index: int, icon_path: Path) -> None:
    draw = ImageDraw.Draw(base)
    accent = slide["accent"]
    navy = (18, 31, 47)
    muted = (84, 97, 112)

    margin = 88
    icon = Image.open(icon_path).convert("RGB").resize((104, 104), Image.Resampling.LANCZOS)
    base.paste(rounded(icon, 24), (W - margin - 104, 82), rounded(icon, 24))

    label_font = font(FONT_MEDIUM, 29)
    label = f"{index:02d}  {slide['app']}"
    label_w, _ = measure(draw, label, label_font)
    draw.rounded_rectangle((margin, 82, margin + label_w + 48, 134), radius=26, fill=(246, 248, 250), outline=(218, 224, 232), width=2)
    draw.text((margin + 24, 92), label, font=label_font, fill=muted)

    title_font = font(FONT_BOLD, 74)
    title_lines = slide.get("title_lines") or wrap_ja(draw, slide["title"], title_font, 1000)
    y = 184
    for line in title_lines[:2]:
        draw.text((margin, y), line, font=title_font, fill=navy)
        y += 88

    body_font = font(FONT_REGULAR, 35)
    body_lines = wrap_ja(draw, slide["body"], body_font, 930)
    y += 18
    for line in body_lines[:2]:
        draw.text((margin, y), line, font=body_font, fill=muted)
        y += 47

    draw.rounded_rectangle((margin, 458, W - margin, 472), radius=7, fill=accent)

    if slide.get("points"):
        point_font = font(FONT_MEDIUM, 27)
        px = margin
        py = 505
        for point in slide["points"][:3]:
            tw, _ = measure(draw, point, point_font)
            draw.rounded_rectangle((px, py, px + tw + 38, py + 46), radius=23, fill=(255, 255, 255), outline=(221, 227, 234), width=2)
            draw.text((px + 19, py + 8), point, font=point_font, fill=(54, 66, 80))
            px += tw + 54


def draw_phone(base: Image.Image, source_path: Path, top: int, crop_top: int = 0) -> None:
    source = Image.open(source_path).convert("RGB")
    if crop_top:
        source = source.crop((0, crop_top, source.width, source.height))

    phone_w = 928
    inner_w = 858
    inner_h = round(source.height * inner_w / source.width)
    source = source.resize((inner_w, inner_h), Image.Resampling.LANCZOS)

    frame_h = min(2040, inner_h + 78)
    frame = Image.new("RGBA", (phone_w, frame_h), (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle((0, 0, phone_w, frame_h), radius=112, fill=(12, 14, 18))
    frame_draw.rounded_rectangle((24, 24, phone_w - 24, frame_h - 24), radius=92, fill=(255, 255, 255))

    screen = rounded(source.crop((0, 0, inner_w, min(inner_h, frame_h - 70))), 72)
    frame.paste(screen, (35, 35), screen)

    x = (W - phone_w) // 2
    paste_shadowed(base, frame, (x, top), 112, alpha=34)


def create_slide(slide: dict, index: int, out_dir: Path, icon_path: Path) -> Path:
    base = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    draw = ImageDraw.Draw(base)
    draw.rectangle((0, H - 780, W, H), fill=slide["wash"])
    soft_circle(draw, (1040, 414), 124, slide["faint"], width=7)
    draw_hexagon(draw, (1018, 754), 96, slide["faint"], width=7)
    draw.rounded_rectangle((0, H - 1040, W, H - 1020), fill=(246, 248, 250))

    draw_header(base, slide, index, icon_path)
    draw_phone(base, slide["source"], top=706, crop_top=slide.get("crop_top", 0))

    footer_font = font(FONT_MEDIUM, 28)
    footer = ImageDraw.Draw(base)
    left = slide["app"]
    right = slide["footer"]
    footer.text((88, H - 92), left, font=footer_font, fill=(93, 105, 118))
    right_w, _ = measure(footer, right, footer_font)
    footer.text((W - 88 - right_w, H - 92), right, font=footer_font, fill=(93, 105, 118))

    out_dir.mkdir(parents=True, exist_ok=True)
    png_path = out_dir / slide["out"]
    jpg_path = out_dir / slide["out"].replace(".png", ".jpg")
    base.convert("RGB").save(png_path, "PNG", optimize=True)
    base.convert("RGB").save(jpg_path, "JPEG", quality=94, optimize=True)
    return png_path


def contact_sheet(paths: list[Path], out_path: Path) -> None:
    thumbs = []
    for path in paths:
        img = Image.open(path).convert("RGB")
        thumb_w = 300
        thumb_h = round(img.height * thumb_w / img.width)
        thumbs.append(img.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS))

    pad = 28
    sheet = Image.new("RGB", (pad * 5 + 300 * 4, max(t.height for t in thumbs) + pad * 2), (244, 246, 248))
    for idx, thumb in enumerate(thumbs):
        x = pad + idx * (300 + pad)
        sheet.paste(thumb, (x, pad))
    sheet.save(out_path, "PNG", optimize=True)


def main() -> None:
    mindvault_slides = [
        {
            "app": "MindVault",
            "title": "メモのつながりを、すぐ確認。",
            "title_lines": ["メモのつながりを、", "すぐ確認。"],
            "body": "起動直後に知識グラフを表示。思考の関係を視覚的にたどれます。",
            "points": ["グラフ表示", "リンク解析", "AI提案"],
            "footer": "知識グラフノート",
            "source": MINDVAULT_SOURCE / "01-graph.png",
            "out": "01-graph.png",
            "accent": (0, 126, 122),
            "wash": (237, 250, 249),
            "faint": (218, 239, 238),
        },
        {
            "app": "MindVault",
            "title": "Markdownで、知識を育てる。",
            "title_lines": ["Markdownで、", "知識を育てる。"],
            "body": "メモを書き、タグとリンクを足すほど、関係の地図が広がります。",
            "points": ["Markdown", "タグ", "wiki link"],
            "footer": "書くほど育つ",
            "source": MINDVAULT_SOURCE / "02-notes.png",
            "out": "02-notes.png",
            "accent": (35, 115, 224),
            "wash": (239, 246, 255),
            "faint": (221, 233, 252),
        },
        {
            "app": "MindVault",
            "title": "ローカルノートを、すばやく検索。",
            "title_lines": ["ローカルノートを、", "すばやく検索。"],
            "body": "保存したメモから候補を探し、対応環境ではオンデバイスAIで整理します。",
            "points": ["ローカル検索", "候補表示", "端末内AI"],
            "footer": "ローカル優先",
            "source": MINDVAULT_SOURCE / "03-search.png",
            "out": "03-search.png",
            "accent": (0, 110, 208),
            "wash": (242, 248, 255),
            "faint": (220, 234, 249),
        },
        {
            "app": "MindVault",
            "title": "大切なメモは、ローカル優先。",
            "title_lines": ["大切なメモは、", "ローカル優先。"],
            "body": "本文を外部AIや独自サーバーへ送らず、安心して整理できます。",
            "points": ["外部送信なし", "広告なし", "設定で確認"],
            "footer": "プライバシー重視",
            "source": MINDVAULT_SOURCE / "04-settings-plan.png",
            "out": "04-privacy.png",
            "accent": (92, 88, 210),
            "wash": (246, 245, 255),
            "faint": (230, 228, 250),
        },
    ]

    grateful_slides = [
        {
            "app": "小さなありがとう日記",
            "title": "今日のありがとうを、写真で残す。",
            "title_lines": ["今日のありがとうを、", "写真で残す。"],
            "body": "小さな感謝を、写真とメモでやさしく記録できます。",
            "points": ["写真日記", "メモ", "端末内保存"],
            "footer": "写真で残す感謝の日記",
            "source": GRATEFUL_SOURCE / "SourceScreensSample" / "01-Moments.png",
            "out": "01-moments.png",
            "accent": (255, 122, 0),
            "wash": (255, 245, 234),
            "faint": (255, 232, 207),
            "crop_top": 0,
        },
        {
            "app": "小さなありがとう日記",
            "title": "続ける力を、見える形に。",
            "title_lines": ["続ける力を、", "見える形に。"],
            "body": "連続記録とバッジで、ふりかえりの習慣を楽しく続けられます。",
            "points": ["連続記録", "バッジ", "習慣化"],
            "footer": "続けるほど楽しい",
            "source": GRATEFUL_SOURCE / "SourceScreensSample" / "02-Achievements.png",
            "out": "02-achievements.png",
            "accent": (224, 72, 92),
            "wash": (255, 244, 247),
            "faint": (250, 224, 230),
            "crop_top": 0,
        },
        {
            "app": "小さなありがとう日記",
            "title": "うれしい瞬間を、すぐ保存。",
            "title_lines": ["うれしい瞬間を、", "すぐ保存。"],
            "body": "タイトル、メモ、写真を選ぶだけ。気持ちが新しいうちに残せます。",
            "points": ["かんたん入力", "写真追加", "すぐ保存"],
            "footer": "その場で記録",
            "source": GRATEFUL_SOURCE / "SourceScreens" / "03-Create.png",
            "out": "03-entry.png",
            "accent": (255, 122, 0),
            "wash": (242, 252, 247),
            "faint": (224, 244, 234),
            "crop_top": 0,
        },
        {
            "app": "小さなありがとう日記",
            "title": "Premiumで、長くふりかえる。",
            "title_lines": ["Premiumで、", "長くふりかえる。"],
            "body": "無制限の記録、書き出し、対応端末でのふりかえりを利用できます。",
            "points": ["無制限記録", "PDF/CSV", "ふりかえり"],
            "footer": "Premium対応",
            "source": GRATEFUL_SOURCE / "IAPReviewScreenshot-PremiumMonthly.png",
            "out": "04-premium.png",
            "accent": (11, 126, 139),
            "wash": (237, 250, 250),
            "faint": (217, 238, 240),
            "crop_top": 0,
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

    readme = OUT_ROOT / "README.md"
    readme.write_text(
        "\n".join(
            [
                "# Digital Agency Style App Store Previews",
                "",
                "Generated candidates inspired by the Digital Agency App Store preview style: white canvas, clear Japanese headline, short explanatory copy, phone mockup, and restrained accent colors.",
                "",
                "- MindVault: `MindVault/iPhone65/`",
                "- 小さなありがとう日記: `SmallThanksDiary/iPhone65/`",
                "- 今日のひとコマ: excluded from this batch; user indicated it should be deleted later because it is superseded by 小さなありがとう日記.",
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
