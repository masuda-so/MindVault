from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "AppStoreAssets" / "Screenshots" / "iPhone65"
OUT_DIR = ROOT / "AppStoreAssets" / "PromotionalImages" / "ja-iPhone65"
ICON_PATH = ROOT / "MindVault" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-iOS-Default-1024x1024@1x.png"

FONT_BOLD = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_MEDIUM = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_REGULAR = "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc"

W, H = 1284, 2778


SLIDES = [
    {
        "source": "01-graph.png",
        "out": "01-graph-connections.png",
        "eyebrow": "MindVault",
        "title": "考えのつながりが見える",
        "subtitle": "起動したらすぐ、メモ同士の関係をグラフで確認。",
        "accent": (10, 187, 174),
        "bg_top": (239, 255, 252),
        "bg_bottom": (249, 251, 255),
    },
    {
        "source": "02-notes.png",
        "out": "02-notes-grow.png",
        "eyebrow": "知識グラフノート",
        "title": "メモを書くほど育つ",
        "subtitle": "Markdown、タグ、リンクを自然に積み重ねられます。",
        "accent": (61, 141, 255),
        "bg_top": (245, 250, 255),
        "bg_bottom": (252, 248, 244),
    },
    {
        "source": "03-search.png",
        "out": "03-local-search.png",
        "eyebrow": "ローカル優先",
        "title": "ローカルノートに質問",
        "subtitle": "関連候補を端末内で探し、対応環境ではオンデバイスAIで回答。",
        "accent": (0, 132, 255),
        "bg_top": (244, 249, 255),
        "bg_bottom": (250, 255, 248),
    },
    {
        "source": "04-settings-plan.png",
        "out": "04-privacy-plan.png",
        "eyebrow": "プライバシー",
        "title": "ローカル優先で安心",
        "subtitle": "ノート本文は外部AIや独自サーバーへ送信しません。",
        "accent": (105, 93, 222),
        "bg_top": (249, 248, 255),
        "bg_bottom": (247, 252, 250),
    },
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def vertical_gradient(top, bottom) -> Image.Image:
    img = Image.new("RGB", (W, H), top)
    draw = ImageDraw.Draw(img)
    for y in range(H):
        ratio = y / max(H - 1, 1)
        color = tuple(int(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        draw.line([(0, y), (W, y)], fill=color)
    return img


def text_width(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0]


def wrap_ja(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    lines = []
    current = ""
    for char in text:
        candidate = current + char
        if current and text_width(draw, candidate, fnt) > max_width:
            lines.append(current)
            current = char
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def rounded_image(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, img.size[0], img.size[1]), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (255, 255, 255, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def paste_shadowed(base: Image.Image, element: Image.Image, xy: tuple[int, int], radius: int, shadow_alpha: int = 42) -> None:
    x, y = xy
    shadow = Image.new("RGBA", element.size, (0, 0, 0, 0))
    shadow_mask = Image.new("L", element.size, 0)
    mask_draw = ImageDraw.Draw(shadow_mask)
    mask_draw.rounded_rectangle((0, 0, element.size[0], element.size[1]), radius=radius, fill=shadow_alpha)
    shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(18)))
    base.paste(shadow, (x, y + 18), shadow)
    base.paste(element, (x, y), element)


def draw_capsule(draw: ImageDraw.ImageDraw, xy, text: str, accent, fnt) -> None:
    x, y = xy
    pad_x = 24
    pad_y = 12
    tw = text_width(draw, text, fnt)
    h = fnt.size + pad_y * 2
    rect = (x, y, x + tw + pad_x * 2, y + h)
    fill = tuple(int(255 * 0.78 + accent[i] * 0.22) for i in range(3))
    draw.rounded_rectangle(rect, radius=h // 2, fill=fill)
    draw.text((x + pad_x, y + pad_y - 2), text, font=fnt, fill=(18, 44, 54))


def draw_title_block(base: Image.Image, slide) -> None:
    draw = ImageDraw.Draw(base)
    accent = slide["accent"]
    x = 88
    y = 106

    icon = Image.open(ICON_PATH).convert("RGB").resize((128, 128), Image.Resampling.LANCZOS)
    base.paste(rounded_image(icon, 28), (W - 88 - 128, 88), rounded_image(icon, 28))

    draw_capsule(draw, (x, y), slide["eyebrow"], accent, font(FONT_MEDIUM, 31))

    title_font = font(FONT_BOLD, 76)
    title_lines = wrap_ja(draw, slide["title"], title_font, 900)
    ty = y + 82
    for line in title_lines:
        draw.text((x, ty), line, font=title_font, fill=(10, 16, 22))
        ty += 92

    sub_font = font(FONT_REGULAR, 36)
    sub_lines = wrap_ja(draw, slide["subtitle"], sub_font, 960)
    sy = ty + 20
    for line in sub_lines[:2]:
        draw.text((x, sy), line, font=sub_font, fill=(79, 88, 98))
        sy += 48

    draw.rounded_rectangle((88, 432, W - 88, 448), radius=8, fill=accent)


def create_slide(slide) -> Path:
    base = vertical_gradient(slide["bg_top"], slide["bg_bottom"]).convert("RGBA")
    draw_title_block(base, slide)

    shot = Image.open(SOURCE_DIR / slide["source"]).convert("RGB")
    phone_w = 1004
    phone_h = round(shot.height * phone_w / shot.width)
    shot = shot.resize((phone_w, phone_h), Image.Resampling.LANCZOS)
    phone = rounded_image(shot, 76)
    paste_shadowed(base, phone, ((W - phone_w) // 2, 548), 76)

    footer = ImageDraw.Draw(base)
    footer_font = font(FONT_MEDIUM, 28)
    footer.text((88, H - 92), "MindVault", font=footer_font, fill=(82, 91, 102))
    footer.text((W - 88 - text_width(footer, "知識グラフノート", footer_font), H - 92), "知識グラフノート", font=footer_font, fill=(82, 91, 102))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / slide["out"]
    base.convert("RGB").save(out_path, "PNG", optimize=True)
    return out_path


def main() -> None:
    paths = [create_slide(slide) for slide in SLIDES]
    for path in paths:
        print(path)


if __name__ == "__main__":
    main()
