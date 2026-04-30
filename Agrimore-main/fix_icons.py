"""
Fix Android launcher icons for all Agrimore apps.
Resizes logo.png to correct mipmap sizes.
"""
from PIL import Image
import os

# Standard Android mipmap sizes for launcher icons
MIPMAP_SIZES = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

# Foreground icon sizes (used in adaptive icons)
DRAWABLE_SIZES = {
    'drawable-mdpi':    108,
    'drawable-hdpi':    162,
    'drawable-xhdpi':   216,
    'drawable-xxhdpi':  324,
    'drawable-xxxhdpi': 432,
}

BASE = r"c:\new\Agrimore-main\Agrimore-main\apps"

# App configs: (app_dir, logo_path, icon_name, has_foreground)
APPS = [
    ("marketplace", os.path.join(BASE, "marketplace", "assets", "images", "logo.png"), "ic_launcher", True),
    ("seller",      os.path.join(BASE, "seller", "assets", "images", "logo.png"),      "launcher_icon", False),
    ("delivery",    os.path.join(BASE, "delivery", "assets", "images", "logo.png"),     "launcher_icon", False),
    ("admin",       os.path.join(BASE, "admin", "assets", "images", "logo.png"),        "ic_launcher", True),
]

def resize_icon(source_path, output_path, size):
    """Resize image to exact size with high-quality antialiasing."""
    img = Image.open(source_path)
    # Convert to RGBA if needed
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    # High-quality resize
    resized = img.resize((size, size), Image.LANCZOS)
    # Save as PNG
    resized.save(output_path, 'PNG', optimize=True)
    print(f"  ✅ {os.path.basename(output_path)} → {size}x{size} ({os.path.getsize(output_path)} bytes)")

def process_app(app_name, logo_path, icon_name, has_foreground):
    print(f"\n{'='*50}")
    print(f"📱 Processing: {app_name.upper()}")
    print(f"{'='*50}")
    
    if not os.path.exists(logo_path):
        print(f"  ❌ Logo not found: {logo_path}")
        return False
    
    res_dir = os.path.join(BASE, app_name, "android", "app", "src", "main", "res")
    
    if not os.path.exists(res_dir):
        print(f"  ❌ Res dir not found: {res_dir}")
        return False
    
    # Generate mipmap icons
    print(f"\n  📐 Generating mipmap icons ({icon_name}.png):")
    for mipmap_dir, size in MIPMAP_SIZES.items():
        target_dir = os.path.join(res_dir, mipmap_dir)
        os.makedirs(target_dir, exist_ok=True)
        output_path = os.path.join(target_dir, f"{icon_name}.png")
        resize_icon(logo_path, output_path, size)
    
    # Generate foreground icons (for adaptive icons)
    if has_foreground:
        print(f"\n  📐 Generating foreground icons:")
        for drawable_dir, size in DRAWABLE_SIZES.items():
            target_dir = os.path.join(res_dir, drawable_dir)
            os.makedirs(target_dir, exist_ok=True)
            output_path = os.path.join(target_dir, "ic_launcher_foreground.png")
            resize_icon(logo_path, output_path, size)
    
    print(f"\n  ✅ {app_name} icons generated successfully!")
    return True

if __name__ == "__main__":
    print("🔧 Agrimore Icon Generator")
    print("="*50)
    
    success_count = 0
    for app_name, logo_path, icon_name, has_foreground in APPS:
        if process_app(app_name, logo_path, icon_name, has_foreground):
            success_count += 1
    
    print(f"\n{'='*50}")
    print(f"✅ Done! {success_count}/{len(APPS)} apps processed.")
