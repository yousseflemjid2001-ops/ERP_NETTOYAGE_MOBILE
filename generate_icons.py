"""
Generate Nettoyage Plus app icons for Android and iOS.
Design: Emerald green gradient background, rounded rect, white 'NP' text with sparkle accent.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont

def draw_rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.ellipse([x0, y0, x0 + radius * 2, y0 + radius * 2], fill=fill)
    draw.ellipse([x1 - radius * 2, y0, x1, y0 + radius * 2], fill=fill)
    draw.ellipse([x0, y1 - radius * 2, x0 + radius * 2, y1], fill=fill)
    draw.ellipse([x1 - radius * 2, y1 - radius * 2, x1, y1], fill=fill)

def make_gradient(size):
    """Create emerald green gradient background."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Top-left: #10b981 (emerald-500), bottom-right: #059669 (emerald-600)
    r1, g1, b1 = 0x10, 0xb9, 0x81   # emerald-500
    r2, g2, b2 = 0x05, 0x96, 0x69   # emerald-600
    for y in range(size):
        t = y / size
        r = int(r1 + (r2 - r1) * t)
        g = int(g1 + (g2 - g1) * t)
        b = int(b1 + (b2 - b1) * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    return img

def draw_sparkle(draw, cx, cy, size, color):
    """Draw a simple 4-point sparkle."""
    r = size // 2
    r_inner = r // 4
    n = 8
    points = []
    for i in range(n):
        angle = math.pi * 2 * i / n - math.pi / 2
        if i % 2 == 0:
            px = cx + r * math.cos(angle)
            py = cy + r * math.sin(angle)
        else:
            px = cx + r_inner * math.cos(angle)
            py = cy + r_inner * math.sin(angle)
        points.append((px, py))
    draw.polygon(points, fill=color)

def generate_icon(size, circle=False):
    """Generate icon at given size. If circle=True, clip to circle (for adaptive icon foreground)."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Gradient background
    bg = make_gradient(size)
    
    padding = int(size * 0.06)
    radius = int(size * 0.22)
    
    if circle:
        # Circle clip mask
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([0, 0, size, size], fill=255)
        img.paste(bg, (0, 0), mask)
    else:
        # Rounded rect mask
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        draw_rounded_rect(mask_draw, [padding, padding, size - padding, size - padding], radius, 255)
        img.paste(bg, (0, 0), mask)
    
    draw = ImageDraw.Draw(img)
    
    # Draw sparkle in top-right corner
    sparkle_size = int(size * 0.22)
    sparkle_x = int(size * 0.72)
    sparkle_y = int(size * 0.26)
    draw_sparkle(draw, sparkle_x, sparkle_y, sparkle_size, (255, 255, 255, 120))
    
    # Draw "NP" text
    font_size = int(size * 0.38)
    font = None
    # Try to find a bold font
    font_paths = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/calibrib.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                font = ImageFont.truetype(fp, font_size)
                break
            except:
                pass
    
    if font is None:
        font = ImageFont.load_default()
    
    text = "NP"
    # Get text bounding box
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (size - text_w) // 2 - bbox[0]
    text_y = (size - text_h) // 2 - bbox[1] + int(size * 0.04)
    
    # Shadow
    draw.text((text_x + int(size*0.02), text_y + int(size*0.02)), text, font=font, fill=(0, 100, 60, 80))
    # White text
    draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255, 255))
    
    return img

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
    icon = generate_icon(size, circle=is_round)
    # Save as RGB PNG (no alpha for Android launcher icons)
    final = Image.new('RGB', (size, size), (255, 255, 255))
    final.paste(icon, (0, 0), icon)
    final.save(out_path, 'PNG', optimize=True)
    print(f"  {rel_path} ({size}x{size})")

print("\nGenerating iOS icons...")
for filename, size in ios_sizes.items():
    out_path = os.path.join(base_ios, filename)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    icon = generate_icon(size, circle=False)
    # iOS needs no alpha
    final = Image.new('RGB', (size, size), (255, 255, 255))
    final.paste(icon, (0, 0), icon)
    final.save(out_path, 'PNG', optimize=True)
    print(f"  {filename} ({size}x{size})")

# Web icons
web_sizes = {
    r'C:\erp-nettoyage-mobile\mobile_app\web\favicon.png': 16,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-192.png': 192,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-512.png': 512,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-maskable-192.png': 192,
    r'C:\erp-nettoyage-mobile\mobile_app\web\icons\Icon-maskable-512.png': 512,
}
print("\nGenerating web icons...")
for out_path, size in web_sizes.items():
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    icon = generate_icon(size, circle=False)
    final = Image.new('RGB', (size, size), (255, 255, 255))
    final.paste(icon, (0, 0), icon)
    final.save(out_path, 'PNG', optimize=True)
    print(f"  {os.path.basename(out_path)} ({size}x{size})")

print("\nDone! All icons generated.")
