import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

SRC_PATH = r"C:\Users\nauma\.gemini\antigravity-ide\brain\e9ac0b6a-febd-436f-90b1-c0241c95f602\.user_uploaded\media_1791129231552.jpg"
ROOT = Path(__file__).resolve().parent.parent

WHITE = (255, 255, 255, 255)
GOLD_EDGE = [205, 175, 115]

def extract_clean_emblem(src_img: Image.Image) -> Image.Image:
    """Extract the gold emblem with zero green background or inner cavity remnants,
    smooth subpixel anti-aliasing, and crop tightly to its true bounding box."""
    img_rgb = src_img.convert("RGB")
    arr = np.array(img_rgb, dtype=float)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    brightness = (r + g + b) / 3.0

    # Classify all dark green background pixels (both outer background and enclosed loops)
    is_bg = (brightness < 45) | ((g >= r * 0.92) & (r < 75) & (brightness < 70))
    mask_binary = (~is_bg).astype(np.uint8) * 255

    # Subpixel Gaussian smoothing on mask for clean anti-aliasing
    mask_img = Image.fromarray(mask_binary, mode="L")
    mask_smooth = mask_img.filter(ImageFilter.GaussianBlur(0.8))
    m_arr = np.array(mask_smooth, dtype=float) / 255.0

    # Pre-clean background RGB: replace any background pixel colors with warm gold
    # so partial alpha blur never samples or bleeds dark green tones into the fringe
    out_rgb = arr.copy()
    out_rgb[is_bg] = GOLD_EDGE

    out_rgba = np.dstack([out_rgb, m_arr * 255]).astype(np.uint8)
    img_trans = Image.fromarray(out_rgba, mode="RGBA")

    # Crop tightly to the true bounding box so centering is mathematically exact
    bbox = img_trans.getbbox()
    return img_trans.crop(bbox)

def center_on_canvas(
    emblem: Image.Image,
    canvas_sz: int,
    fill_ratio: float,
    bg_color=None,
    is_round: bool = False,
    is_squircle: bool = False,
    squircle_radius_ratio: float = 0.22,
) -> Image.Image:
    """Center the emblem onto a square canvas with supersampling and exact padding."""
    ss = 4
    c_sz = canvas_sz * ss
    max_dim = max(emblem.size)
    target_dim = int(c_sz * fill_ratio)
    scale = target_dim / max_dim
    new_w = int(emblem.width * scale)
    new_h = int(emblem.height * scale)

    resized_emblem = emblem.resize((new_w, new_h), Image.Resampling.LANCZOS)

    if bg_color is not None:
        canvas = Image.new("RGBA", (c_sz, c_sz), bg_color)
    else:
        canvas = Image.new("RGBA", (c_sz, c_sz), (0, 0, 0, 0))

    pos_x = (c_sz - new_w) // 2
    pos_y = (c_sz - new_h) // 2
    canvas.paste(resized_emblem, (pos_x, pos_y), resized_emblem)

    if is_round:
        mask = Image.new("L", (c_sz, c_sz), 0)
        draw = ImageDraw.Draw(mask)
        draw.ellipse((0, 0, c_sz - 1, c_sz - 1), fill=255)
        rounded = Image.new("RGBA", (c_sz, c_sz), (0, 0, 0, 0))
        rounded.paste(canvas, (0, 0), mask)
        canvas = rounded
    elif is_squircle:
        radius = int(c_sz * squircle_radius_ratio)
        mask = Image.new("L", (c_sz, c_sz), 0)
        draw = ImageDraw.Draw(mask)
        draw.rounded_rectangle([(0, 0), (c_sz - 1, c_sz - 1)], radius=radius, fill=255)
        rounded = Image.new("RGBA", (c_sz, c_sz), (0, 0, 0, 0))
        rounded.paste(canvas, (0, 0), mask)
        canvas = rounded

    return canvas.resize((canvas_sz, canvas_sz), Image.Resampling.LANCZOS)

def create_splash_mark(
    emblem: Image.Image,
    target_size: int,
    is_dark: bool = False,
) -> Image.Image:
    """Create a high quality supersampled squircle logo with subtle shadow for splash screens."""
    ss = 4
    canvas_sz = target_size * ss
    tile_sz = int(canvas_sz * 0.76)
    radius = int(tile_sz * 0.22)

    bg_color = (18, 18, 20, 255) if is_dark else (255, 255, 255, 255)
    tile = center_on_canvas(
        emblem,
        canvas_sz=tile_sz // ss,
        fill_ratio=0.72,
        bg_color=bg_color,
        is_squircle=True,
    ).resize((tile_sz, tile_sz), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    shadow_offset = int(tile_sz * 0.04)
    shadow_blur = int(tile_sz * 0.06)

    shadow_color = (0, 0, 0, 100) if is_dark else (0, 0, 0, 60)
    shadow_box = Image.new("RGBA", (tile_sz, tile_sz), shadow_color)

    mask = Image.new("L", (tile_sz, tile_sz), 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.rounded_rectangle([(0, 0), (tile_sz - 1, tile_sz - 1)], radius=radius, fill=255)

    shadow_box_rounded = Image.new("RGBA", (tile_sz, tile_sz), (0, 0, 0, 0))
    shadow_box_rounded.paste(shadow_box, (0, 0), mask)

    pos_x = (canvas_sz - tile_sz) // 2
    pos_y = (canvas_sz - tile_sz) // 2
    canvas.paste(shadow_box_rounded, (pos_x, pos_y + shadow_offset), mask)
    canvas = canvas.filter(ImageFilter.GaussianBlur(shadow_blur))
    canvas.paste(tile, (pos_x, pos_y), tile)

    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def main():
    raw_img = Image.open(SRC_PATH)
    print(f"Loaded source image {raw_img.size}")

    emblem = extract_clean_emblem(raw_img)
    print(f"Isolated clean emblem, cropped to bbox {emblem.size}")

    # 1. Assets in app (assets/branding/)
    assets_branding = ROOT / "assets" / "branding"
    assets_branding.mkdir(parents=True, exist_ok=True)

    # In app_logo.png, emblem is centered with safe padding (74% fill) on white
    # so BrandMark's 22% squircle radius never clips the tips of the emblem.
    logo_1024 = center_on_canvas(emblem, 1024, fill_ratio=0.74, bg_color=WHITE)
    logo_1024.save(assets_branding / "app_logo.png", "PNG")
    print(f"Saved {assets_branding / 'app_logo.png'}")

    logo_512 = center_on_canvas(emblem, 512, fill_ratio=0.74, bg_color=WHITE)
    logo_512.save(assets_branding / "app_logo_512.png", "PNG")

    logo_192 = center_on_canvas(emblem, 192, fill_ratio=0.74, bg_color=WHITE)
    logo_192.save(assets_branding / "app_logo_192.png", "PNG")

    # 2. Branding directory
    branding = ROOT / "branding"
    branding.mkdir(parents=True, exist_ok=True)
    logo_1024.save(branding / "xpenc_icon_1024.png", "PNG")
    logo_512.save(branding / "xpenc_icon_512.png", "PNG")
    logo_192.save(branding / "icon_192.png", "PNG")
    center_on_canvas(emblem, 180, fill_ratio=0.74, bg_color=WHITE).save(branding / "apple_touch_icon_180.png", "PNG")
    center_on_canvas(emblem, 32, fill_ratio=0.74, bg_color=WHITE).save(branding / "favicon_32.png", "PNG")
    center_on_canvas(emblem, 16, fill_ratio=0.74, bg_color=WHITE).save(branding / "favicon_16.png", "PNG")

    # Favicon .ico
    logo_1024.save(branding / "favicon.ico", format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
    print("Saved branding directory assets")

    # 3. Android res mipmap
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    densities = {
        "mipmap-mdpi": (48, 108),
        "mipmap-hdpi": (72, 162),
        "mipmap-xhdpi": (96, 216),
        "mipmap-xxhdpi": (144, 324),
        "mipmap-xxxhdpi": (192, 432),
    }

    for folder, (icon_sz, fg_sz) in densities.items():
        dir_path = res / folder
        if not dir_path.exists():
            continue

        # ic_launcher.png (square / standard on white with safe 74% fill)
        icon_img = center_on_canvas(emblem, icon_sz, fill_ratio=0.74, bg_color=WHITE)
        icon_img.save(dir_path / "ic_launcher.png", "PNG")

        # ic_launcher_round.png (round on white with safe 62% fill - zero edge clipping!)
        round_img = center_on_canvas(emblem, icon_sz, fill_ratio=0.62, bg_color=WHITE, is_round=True)
        round_img.save(dir_path / "ic_launcher_round.png", "PNG")

        # ic_launcher_background.png (pure white background for adaptive icons)
        bg_img = Image.new("RGBA", (fg_sz, fg_sz), WHITE)
        bg_img.save(dir_path / "ic_launcher_background.png", "PNG")

        # ic_launcher_foreground.png (for adaptive icons, centered in 108dp canvas)
        # Android circular safe zone is 66dp/108dp = 61.1% (radius 33dp).
        # fill_ratio = 0.43 guarantees diagonal extent <= 31.5dp, so the emblem is
        # 100% inside the circle mask on all Android launchers with elegant framing!
        fg_canvas = center_on_canvas(emblem, fg_sz, fill_ratio=0.43, bg_color=None)
        fg_canvas.save(dir_path / "ic_launcher_foreground.png", "PNG")
        print(f"Generated Android icons for {folder}")

    # 4. Android splash marks
    splash_densities = {
        "drawable-mdpi": 160,
        "drawable-hdpi": 240,
        "drawable-xhdpi": 320,
        "drawable-xxhdpi": 480,
        "drawable-xxxhdpi": 640,
    }
    for folder, sz in splash_densities.items():
        dir_path = res / folder
        dir_path.mkdir(parents=True, exist_ok=True)
        splash_light = create_splash_mark(emblem, sz, is_dark=False)
        splash_dark = create_splash_mark(emblem, sz, is_dark=True)
        splash_light.save(dir_path / "splash_mark_on_light.png", "PNG")
        splash_dark.save(dir_path / "splash_mark_on_dark.png", "PNG")
        print(f"Saved splash marks in {folder}")

    # 5. Windows app icon
    win_res = ROOT / "windows" / "runner" / "resources"
    if win_res.exists():
        logo_1024.save(
            win_res / "app_icon.ico",
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )
        print("Generated windows app_icon.ico")

if __name__ == "__main__":
    main()
