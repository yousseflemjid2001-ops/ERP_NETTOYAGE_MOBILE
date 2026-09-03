"""
Generate Nettoyage Plus official app icons for Android, iOS and Web from the official vector logo.
Design: Circular Sapphire to Cyan gradient background with stylized 'N' and sparkle.
"""
import os
import math
from PIL import Image, ImageDraw

def make_logo(size, circle=True):
    # Render at 2x for supersampled anti-aliasing
    render_size = size * 2
    scale = render_size / 64.0

    img = Image.new('RGBA', (render_size, render_size), (0, 0, 0, 0))

    # Diagonal linear gradient (#0047AB to #00C4CC)
    c_img = Image.new('RGBA', (render_size, render_size), (0, 0, 0, 0))
    for y in range(render_size):
        for x in range(render_size):
            t = (x + y) / (2.0 * render_size)
            r = int(0x00 + (0x00 - 0x00) * t)
            g = int(0x47 + (0xC4 - 0x47) * t)
            b = int(0xAB + (0xCC - 0xAB) * t)
            c_img.putpixel((x, y), (r, g, b, 255))

    # Mask circle
    mask = Image.new('L', (render_size, render_size), 0)
    m_draw = ImageDraw.Draw(mask)
    if circle:
        cx, cy, r = 32 * scale, 32 * scale, 30 * scale
        m_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    else:
        # Rounded rect
        radius = int(render_size * 0.22)
        padding = int(render_size * 0.04)
        m_draw.rounded_rectangle([padding, padding, render_size - padding, render_size - padding], radius=radius, fill=255)

    img.paste(c_img, (0, 0), mask)
    draw = ImageDraw.Draw(img)

    # Letter N
    n_poly = [
        (18 * scale, 18 * scale),
        (18 * scale, 46 * scale),
        (24 * scale, 46 * scale),
        (24 * scale, 30 * scale),
        (40 * scale, 46 * scale),
        (46 * scale, 46 * scale),
        (46 * scale, 18 * scale),
        (40 * scale, 18 * scale),
        (40 * scale, 34 * scale),
        (24 * scale, 18 * scale),
    ]
    draw.polygon(n_poly, fill=(255, 255, 255, 255))

    # 4-point star sparkle
    def bezier_curve(p0, p1, p2, p3, steps=16):
        pts = []
        for i in range(steps + 1):
            t = i / steps
            u = 1 - t
            x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
            y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
            pts.append((x, y))
        return pts

    star_pts = []
    star_pts.extend(bezier_curve((42*scale, 22*scale), (42*scale, 26*scale), (38*scale, 30*scale), (34*scale, 30*scale)))
    star_pts.extend(bezier_curve((34*scale, 30*scale), (38*scale, 30*scale), (42*scale, 34*scale), (42*scale, 38*scale))[1:])
    star_pts.extend(bezier_curve((42*scale, 38*scale), (42*scale, 34*scale), (46*scale, 30*scale), (50*scale, 30*scale))[1:])
    star_pts.extend(bezier_curve((50*scale, 30*scale), (46*scale, 30*scale), (42*scale, 26*scale), (42*scale, 22*scale))[1:])

    draw.polygon(star_pts, fill=(255, 255, 255, 255))

    # Downsample with Lanczos for smooth antialiasing
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

# Android mipmap sizes
android_sizes = {
    'mipmap-mdpi/ic_launcher.png': 48,
    'mipmap-hdpi/ic_launcher.png': 72,
    'mipmap-xhdpi/ic_launcher.png': 96,
    'mipmap-xxhdpi/ic_launcher.png': 144,
    'mipmap-xxxhdpi/ic_launcher.png': 192,
    # Round icons
    'mipmap-mdpi/ic_launcher_round.png': 48,
    'mipmap-hdpi/ic_launcher_round.png': 72,
    'mipmap-xhdpi/ic_launcher_round.png': 96,
    'mipmap-xxhdpi/ic_launcher_round.png': 144,
    'mipmap-xxxhdpi/ic_launcher_round.png': 192,
}

# iOS icon sizes
ios_sizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}

base_android = r'C:\erp-nettoyage-mobile\mobile_app\android\app\src\main\res'
base_ios = r'C:\erp-nettoyage-mobile\mobile_app\ios\Runner\Assets.xcassets\AppIcon.appiconset'

print("Generating Android icons...")
for rel_path, size in android_sizes.items():
    out_path = os.path.join(base_android, rel_path)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    is_round = 'round' in rel_path
    icon = make_logo(size, circle=is_round)
    icon.save(out_path, 'PNG', optimize=True)
    print(f"  {rel_path} ({size}x{size})")

print("\nGenerating iOS icons...")
for filename, size in ios_sizes.items():
    out_path = os.path.join(base_ios, filename)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    icon = make_logo(size, circle=False)
    # iOS launcher needs RGB with background
    final = Image.new('RGB', (size, size), (255, 255, 255))
    final.paste(icon, (0, 0), icon)
    final.save(out_path, 'PNG', optimize=True)
    print(f"  {filename} ({size}x{size})")

# Web icons
web_sizes = {
    r'C:\erp-nettoyage-mobile\mobile_app\web\favicon.png': 64,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-192.png': 192,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-512.png': 512,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-maskable-192.png': 192,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-maskable-512.png': 512,
}
print("\nGenerating web icons...")
for out_path, size in web_sizes.items():
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    icon = make_logo(size, circle=True)
    icon.save(out_path, 'PNG', optimize=True)
    print(f"  {os.path.basename(out_path)} ({size}x{size})")

print("\nDone! All icons generated from official vector logo.")
