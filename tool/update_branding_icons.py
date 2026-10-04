import os
from pathlib import Path
from PIL import Image, ImageDraw

SRC_PATH = r"C:\Users\nauma\.gemini\antigravity-ide\brain\e9ac0b6a-febd-436f-90b1-c0241c95f602\.user_uploaded\media_1791129231552.jpg"
ROOT = Path(__file__).resolve().parent.parent

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

def main():
    img = Image.open(SRC_PATH).convert("RGBA")
    print(f"Loaded image {img.size}")

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
        # ic_launcher.png (square / standard)
        icon_img = img.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS)
        icon_img.save(dir_path / "ic_launcher.png", "PNG")

        # ic_launcher_round.png
        round_img = make_round(icon_img)
        round_img.save(dir_path / "ic_launcher_round.png", "PNG")

        # ic_launcher_foreground.png (for adaptive icons, centered in 108dp canvas)
        fg_canvas = Image.new("RGBA", (fg_sz, fg_sz), (0, 0, 0, 0))
        # icon takes up ~66% of the adaptive canvas
        inner_sz = int(fg_sz * 0.72)
        inner_img = img.resize((inner_sz, inner_sz), Image.Resampling.LANCZOS)
        offset = ((fg_sz - inner_sz) // 2, (fg_sz - inner_sz) // 2)
        fg_canvas.paste(inner_img, offset)
        fg_canvas.save(dir_path / "ic_launcher_foreground.png", "PNG")
        print(f"Generated Android icons for {folder}")

    # 4. Windows app icon
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
