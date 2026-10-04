import os
from pathlib import Path
from collections import deque
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

SRC_PATH = r"C:\Users\nauma\.gemini\antigravity-ide\brain\e9ac0b6a-febd-436f-90b1-c0241c95f602\.user_uploaded\media_1791129231552.jpg"
ROOT = Path(__file__).resolve().parent.parent

WHITE = (255, 255, 255)

def extract_emblem_on_white(src_img: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Isolate emblem from the green background using flood-fill and anti-aliasing.
    Returns:
        (emblem_on_white, emblem_transparent)
    """
    img_rgb = src_img.convert("RGB")
    arr = np.array(img_rgb)
    h, w, _ = arr.shape
    
    # Identify outer dark green background
    is_dark_green = (arr[:, :, 0] < 55) & (arr[:, :, 1] < 100) & (arr[:, :, 2] < 70)

    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for y in range(h):
        for x in (0, w - 1):
            if is_dark_green[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            if is_dark_green[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if is_dark_green[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))

    # Binary alpha mask: 0 for background, 255 for emblem
    alpha = (~visited).astype(np.uint8) * 255
    alpha_img = Image.fromarray(alpha, mode="L")
    alpha_smooth = alpha_img.filter(ImageFilter.GaussianBlur(0.7))

    # Transparent emblem
    emblem_transparent = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    emblem_transparent.paste(img_rgb, (0, 0), alpha_smooth)

    # Composite on white
    white_bg = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    emblem_on_white = Image.alpha_composite(white_bg, emblem_transparent)

    return emblem_on_white, emblem_transparent

def make_round(img: Image.Image) -> Image.Image:
    """Mask image into a circle with anti-aliased edge."""
    size = img.size
    mask = Image.new("L", (size[0] * 4, size[1] * 4), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size[0] * 4 - 1, size[1] * 4 - 1), fill=255)
    mask = mask.resize(size, Image.Resampling.LANCZOS)
    rounded = Image.new("RGBA", size, (0, 0, 0, 0))
    rounded.paste(img.convert("RGBA"), (0, 0), mask)
    return rounded

def create_rounded_logo_with_shadow(img: Image.Image, target_size: int, logo_ratio: float = 0.82) -> Image.Image:
    """Create a high quality supersampled squircle logo with subtle shadow for splash screens."""
    ss = 4
    canvas_sz = target_size * ss
    logo_sz = int(canvas_sz * logo_ratio)
    radius = int(logo_sz * 0.22)
    
    mask = Image.new("L", (logo_sz, logo_sz), 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.rounded_rectangle([(0, 0), (logo_sz - 1, logo_sz - 1)], radius=radius, fill=255)
    
    resized_logo = img.resize((logo_sz, logo_sz), Image.Resampling.LANCZOS)
    rounded_logo = Image.new("RGBA", (logo_sz, logo_sz), (0, 0, 0, 0))
    rounded_logo.paste(resized_logo, (0, 0), mask)
    
    canvas = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
    shadow_offset = int(logo_sz * 0.04)
    shadow_blur = int(logo_sz * 0.06)
    shadow_box = Image.new("RGBA", (logo_sz, logo_sz), (0, 0, 0, 70))
    shadow_box_rounded = Image.new("RGBA", (logo_sz, logo_sz), (0, 0, 0, 0))
    shadow_box_rounded.paste(shadow_box, (0, 0), mask)
    
    pos_x = (canvas_sz - logo_sz) // 2
    pos_y = (canvas_sz - logo_sz) // 2
    canvas.paste(shadow_box_rounded, (pos_x, pos_y + shadow_offset), mask)
    canvas = canvas.filter(ImageFilter.GaussianBlur(shadow_blur))
    canvas.paste(rounded_logo, (pos_x, pos_y), mask)
    
    return canvas.resize((target_size, target_size), Image.Resampling.LANCZOS)

def main():
    raw_img = Image.open(SRC_PATH)
    print(f"Loaded source image {raw_img.size}")
    
    img, img_transparent = extract_emblem_on_white(raw_img)
    print("Isolated emblem and replaced green background with white.")

    # 1. Assets in app
    assets_branding = ROOT / "assets" / "branding"
    assets_branding.mkdir(parents=True, exist_ok=True)
    
    img_1024 = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    img_1024.save(assets_branding / "app_logo.png", "PNG")
    print(f"Saved {assets_branding / 'app_logo.png'}")

    img_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    img_512.save(assets_branding / "app_logo_512.png", "PNG")

    img_192 = img.resize((192, 192), Image.Resampling.LANCZOS)
    img_192.save(assets_branding / "app_logo_192.png", "PNG")

    # 2. Branding directory
    branding = ROOT / "branding"
    branding.mkdir(parents=True, exist_ok=True)
    img_1024.save(branding / "xpenc_icon_1024.png", "PNG")
    img_512.save(branding / "xpenc_icon_512.png", "PNG")
    img_192.save(branding / "icon_192.png", "PNG")
    img.resize((180, 180), Image.Resampling.LANCZOS).save(branding / "apple_touch_icon_180.png", "PNG")
    img.resize((32, 32), Image.Resampling.LANCZOS).save(branding / "favicon_32.png", "PNG")
    img.resize((16, 16), Image.Resampling.LANCZOS).save(branding / "favicon_16.png", "PNG")

    # Favicon .ico
    img.save(branding / "favicon.ico", format="ICO", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
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
        # ic_launcher.png (square / standard on white)
        icon_img = img.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS)
        icon_img.save(dir_path / "ic_launcher.png", "PNG")

        # ic_launcher_round.png
        round_img = make_round(icon_img)
        round_img.save(dir_path / "ic_launcher_round.png", "PNG")

        # ic_launcher_background.png (pure white background for adaptive icons)
        bg_img = Image.new("RGBA", (fg_sz, fg_sz), (*WHITE, 255))
        bg_img.save(dir_path / "ic_launcher_background.png", "PNG")

        # ic_launcher_foreground.png (for adaptive icons, centered in 108dp canvas)
        fg_canvas = Image.new("RGBA", (fg_sz, fg_sz), (0, 0, 0, 0))
        inner_sz = int(fg_sz * 0.72)
        inner_img = img_transparent.resize((inner_sz, inner_sz), Image.Resampling.LANCZOS)
        offset = ((fg_sz - inner_sz) // 2, (fg_sz - inner_sz) // 2)
        fg_canvas.paste(inner_img, offset)
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
        splash_img = create_rounded_logo_with_shadow(img, sz)
        splash_img.save(dir_path / "splash_mark_on_light.png", "PNG")
        splash_img.save(dir_path / "splash_mark_on_dark.png", "PNG")
        print(f"Saved splash marks in {folder}")

    # 5. Windows app icon
    win_res = ROOT / "windows" / "runner" / "resources"
    if win_res.exists():
        img.save(
            win_res / "app_icon.ico",
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )
        print("Generated windows app_icon.ico")

if __name__ == "__main__":
    main()
