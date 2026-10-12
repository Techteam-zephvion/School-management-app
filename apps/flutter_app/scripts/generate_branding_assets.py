#!/usr/bin/env python3
"""
Schoolic Branding Asset Generator
Generates official minimalist 'S.' logo, application icons, and favicons
directly from bundled Switzer typography using FreeType mathematical outlines
and Pillow high-resolution rasterization.
"""

import os
import sys
import ctypes
import re
from PIL import Image, ImageDraw, ImageFont

# -----------------------------------------------------------------------------
# 1. FreeType CTypes Setup for Precise Glyph Outline Extraction
# -----------------------------------------------------------------------------

ft = ctypes.CDLL('libfreetype.so.6')

class FT_BBox(ctypes.Structure):
    _fields_ = [('xMin', ctypes.c_long), ('yMin', ctypes.c_long), ('xMax', ctypes.c_long), ('yMax', ctypes.c_long)]

class FT_Vector(ctypes.Structure):
    _fields_ = [('x', ctypes.c_long), ('y', ctypes.c_long)]

class FT_Outline(ctypes.Structure):
    _fields_ = [
        ('n_contours', ctypes.c_short),
        ('n_points', ctypes.c_short),
        ('points', ctypes.POINTER(FT_Vector)),
        ('tags', ctypes.c_char_p),
        ('contours', ctypes.POINTER(ctypes.c_short)),
        ('flags', ctypes.c_int),
    ]

class FT_Glyph_Metrics(ctypes.Structure):
    _fields_ = [
        ('width', ctypes.c_long), ('height', ctypes.c_long),
        ('horiBearingX', ctypes.c_long), ('horiBearingY', ctypes.c_long),
        ('horiAdvance', ctypes.c_long),
        ('vertBearingX', ctypes.c_long), ('vertBearingY', ctypes.c_long),
        ('vertAdvance', ctypes.c_long),
    ]

class FT_Bitmap(ctypes.Structure):
    _fields_ = [
        ('rows', ctypes.c_uint), ('width', ctypes.c_uint), ('pitch', ctypes.c_int),
        ('buffer', ctypes.c_void_p), ('num_grays', ctypes.c_ushort),
        ('pixel_mode', ctypes.c_ubyte), ('palette_mode', ctypes.c_ubyte),
        ('palette', ctypes.c_void_p),
    ]

class FT_GlyphSlotRec(ctypes.Structure):
    _fields_ = [
        ('library', ctypes.c_void_p), ('face', ctypes.c_void_p), ('next', ctypes.c_void_p),
        ('glyph_index', ctypes.c_uint),
        ('generic_data', ctypes.c_void_p), ('generic_finalizer', ctypes.c_void_p),
        ('metrics', FT_Glyph_Metrics),
        ('linearHoriAdvance', ctypes.c_long), ('linearVertAdvance', ctypes.c_long),
        ('advance', FT_Vector),
        ('format', ctypes.c_uint32),
        ('bitmap', FT_Bitmap),
        ('bitmap_left', ctypes.c_int), ('bitmap_top', ctypes.c_int),
        ('outline', FT_Outline),
    ]

class FT_FaceRec(ctypes.Structure):
    _fields_ = [
        ('num_faces', ctypes.c_long), ('face_index', ctypes.c_long),
        ('face_flags', ctypes.c_long), ('style_flags', ctypes.c_long),
        ('num_glyphs', ctypes.c_long),
        ('family_name', ctypes.c_char_p), ('style_name', ctypes.c_char_p),
        ('num_fixed_sizes', ctypes.c_int), ('available_sizes', ctypes.c_void_p),
        ('num_charmaps', ctypes.c_int), ('charmaps', ctypes.c_void_p),
        ('generic_data', ctypes.c_void_p), ('generic_finalizer', ctypes.c_void_p),
        ('bbox', FT_BBox),
        ('units_per_EM', ctypes.c_ushort),
        ('ascender', ctypes.c_short), ('descender', ctypes.c_short), ('height', ctypes.c_short),
        ('max_advance_width', ctypes.c_short), ('max_advance_height', ctypes.c_short),
        ('underline_position', ctypes.c_short), ('underline_thickness', ctypes.c_short),
        ('glyph', ctypes.POINTER(FT_GlyphSlotRec)),
    ]

move_to_func = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(FT_Vector), ctypes.c_void_p)
line_to_func = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(FT_Vector), ctypes.c_void_p)
conic_to_func = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(FT_Vector), ctypes.POINTER(FT_Vector), ctypes.c_void_p)
cubic_to_func = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.POINTER(FT_Vector), ctypes.POINTER(FT_Vector), ctypes.POINTER(FT_Vector), ctypes.c_void_p)

class FT_Outline_Funcs(ctypes.Structure):
    _fields_ = [
        ('move_to', move_to_func), ('line_to', line_to_func),
        ('conic_to', conic_to_func), ('cubic_to', cubic_to_func),
        ('shift', ctypes.c_int), ('delta', ctypes.c_long),
    ]

ft.FT_Outline_Decompose.argtypes = [ctypes.POINTER(FT_Outline), ctypes.POINTER(FT_Outline_Funcs), ctypes.c_void_p]
ft.FT_Outline_Get_BBox.argtypes = [ctypes.POINTER(FT_Outline), ctypes.POINTER(FT_BBox)]

def extract_svg_path(font_path: str, scale: float = 1.0, offset_x: float = 0.0, offset_y: float = 0.0):
    """Extracts exact SVG path for 'S.' from the given font file."""
    d_parts = []
    dx = 0
    in_contour = False

    def on_move_to(to, user):
        nonlocal in_contour
        if in_contour:
            d_parts.append('Z')
        in_contour = True
        px = round(offset_x + (to.contents.x + dx) * scale, 2)
        py = round(offset_y + (-to.contents.y) * scale, 2)
        d_parts.append(f'M {px} {py}')
        return 0

    def on_line_to(to, user):
        px = round(offset_x + (to.contents.x + dx) * scale, 2)
        py = round(offset_y + (-to.contents.y) * scale, 2)
        d_parts.append(f'L {px} {py}')
        return 0

    def on_conic_to(ctrl, to, user):
        cx = round(offset_x + (ctrl.contents.x + dx) * scale, 2)
        cy = round(offset_y + (-ctrl.contents.y) * scale, 2)
        px = round(offset_x + (to.contents.x + dx) * scale, 2)
        py = round(offset_y + (-to.contents.y) * scale, 2)
        d_parts.append(f'Q {cx} {cy} {px} {py}')
        return 0

    def on_cubic_to(c1, c2, to, user):
        c1x = round(offset_x + (c1.contents.x + dx) * scale, 2)
        c1y = round(offset_y + (-c1.contents.y) * scale, 2)
        c2x = round(offset_x + (c2.contents.x + dx) * scale, 2)
        c2y = round(offset_y + (-c2.contents.y) * scale, 2)
        px = round(offset_x + (to.contents.x + dx) * scale, 2)
        py = round(offset_y + (-to.contents.y) * scale, 2)
        d_parts.append(f'C {c1x} {c1y} {c2x} {c2y} {px} {py}')
        return 0

    funcs = FT_Outline_Funcs(
        move_to=move_to_func(on_move_to), line_to=line_to_func(on_line_to),
        conic_to=conic_to_func(on_conic_to), cubic_to=cubic_to_func(on_cubic_to),
        shift=0, delta=0,
    )

    lib = ctypes.c_void_p()
    ft.FT_Init_FreeType(ctypes.byref(lib))
    face = ctypes.POINTER(FT_FaceRec)()
    ft.FT_New_Face(lib, font_path.encode('utf-8'), 0, ctypes.byref(face))

    # Decompose 'S'
    ft.FT_Load_Char(face, ord('S'), 1) # 1 = FT_LOAD_NO_SCALE
    slot = face.contents.glyph.contents
    ft.FT_Outline_Decompose(ctypes.byref(slot.outline), ctypes.byref(funcs), None)

    # Decompose '.'
    dx = slot.advance.x
    ft.FT_Load_Char(face, ord('.'), 1)
    slot = face.contents.glyph.contents
    ft.FT_Outline_Decompose(ctypes.byref(slot.outline), ctypes.byref(funcs), None)
    if in_contour:
        d_parts.append('Z')

    return ' '.join(d_parts)

# -----------------------------------------------------------------------------
# 2. Main Generation Routine
# -----------------------------------------------------------------------------

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    flutter_root = os.path.join(repo_root, 'apps/flutter_app')
    font_path = os.path.join(flutter_root, 'assets/fonts/switzer/Switzer-Bold.ttf')
    
    if not os.path.exists(font_path):
        print(f"Error: font file not found at {font_path}")
        sys.exit(1)

    print(f"Using font: {font_path}")

    # Output directories
    branding_dir = os.path.join(flutter_root, 'assets/branding')
    web_dir = os.path.join(flutter_root, 'web')
    web_icons_dir = os.path.join(web_dir, 'icons')
    android_res = os.path.join(flutter_root, 'android/app/src/main/res')
    windows_res = os.path.join(flutter_root, 'windows/runner/resources')

    os.makedirs(branding_dir, exist_ok=True)
    os.makedirs(web_icons_dir, exist_ok=True)
    os.makedirs(windows_res, exist_ok=True)

    # -------------------------------------------------------------------------
    # A. Standalone SVG Wordmark: schoolic-logo.svg
    # -------------------------------------------------------------------------
    # In Switzer-Bold at UPM 1000:
    # 'S': xMin=27, xMax=602, yMin=-16, yMax=696, advance=629
    # '.': xMin=48, xMax=208, yMin=0, yMax=161, advance=256
    # Combined with dx=629:
    # xMin = 27, xMax = 629 + 208 = 837 (width = 810)
    # yMin = -16, yMax = 696 (height = 712)
    #
    # We normalize to (0, 0) viewBox:
    # offset_x = -27
    # offset_y = 696
    logo_path = extract_svg_path(font_path, scale=1.0, offset_x=-27.0, offset_y=696.0)

    svg_logo = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 810 712" width="810" height="712">
  <path d="{logo_path}" fill="#111111"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-logo.svg'), 'w') as f:
        f.write(svg_logo)
    print("Created: assets/branding/schoolic-logo.svg")

    # -------------------------------------------------------------------------
    # B. Standalone Raster PNGs (Black and White on Transparent)
    # -------------------------------------------------------------------------
    # Render at high resolution (1620x1424 = 2x)
    img_black = Image.new('RGBA', (1620, 1424), (0, 0, 0, 0))
    img_white = Image.new('RGBA', (1620, 1424), (0, 0, 0, 0))
    draw_black = ImageDraw.Draw(img_black)
    draw_white = ImageDraw.Draw(img_white)
    
    font_hi = ImageFont.truetype(font_path, 1424)
    # Bounding box of S. with font size 1424
    bbox = font_hi.getbbox('S.')
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    bx = (1620 - bw) // 2 - bbox[0]
    by = (1424 - bh) // 2 - bbox[1]

    draw_black.text((bx, by), 'S.', font=font_hi, fill=(17, 17, 17, 255))
    draw_white.text((bx, by), 'S.', font=font_hi, fill=(255, 255, 255, 255))

    img_black.save(os.path.join(branding_dir, 'schoolic-logo-black.png'))
    img_white.save(os.path.join(branding_dir, 'schoolic-logo-white.png'))
    print("Created: assets/branding/schoolic-logo-black.png")
    print("Created: assets/branding/schoolic-logo-white.png")

    # -------------------------------------------------------------------------
    # C. Application Icon Vector: schoolic-icon.svg (1024x1024)
    # -------------------------------------------------------------------------
    # Center S. within 1024x1024 with width 560
    scale_icon = 560.0 / 810.0
    # Optical center of mark: cx = (27 + 837) / 2 = 432, cy = (-16 + 696) / 2 = 340
    offset_x_icon = 512.0 - 432.0 * scale_icon
    offset_y_icon = 512.0 + 340.0 * scale_icon

    icon_path_svg = extract_svg_path(font_path, scale=scale_icon, offset_x=offset_x_icon, offset_y=offset_y_icon)

    svg_icon = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" rx="225" ry="225" fill="#000000"/>
  <path d="{icon_path_svg}" fill="#FFFFFF"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-icon.svg'), 'w') as f:
        f.write(svg_icon)
    print("Created: assets/branding/schoolic-icon.svg")

    # -------------------------------------------------------------------------
    # D. High-Resolution Master PNGs (1024x1024)
    # -------------------------------------------------------------------------
    # 1. Rounded rectangle master (standard app launchers, PWA, Windows)
    icon_1024 = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    draw_1024 = ImageDraw.Draw(icon_1024)
    draw_1024.rounded_rectangle([(0, 0), (1024, 1024)], radius=225, fill=(0, 0, 0, 255))
    
    font_icon = ImageFont.truetype(font_path, 630)
    bbox_icon = font_icon.getbbox('S.')
    iw = bbox_icon[2] - bbox_icon[0]
    ih = bbox_icon[3] - bbox_icon[1]
    ix = (1024 - iw) // 2 - bbox_icon[0]
    iy = (1024 - ih) // 2 - bbox_icon[1]
    draw_1024.text((ix, iy), 'S.', font=font_icon, fill=(255, 255, 255, 255))
    icon_1024.save(os.path.join(branding_dir, 'schoolic-icon-1024.png'))
    print("Created: assets/branding/schoolic-icon-1024.png")

    # 2. Full-bleed square master (for maskable PWA and Apple Touch Icon)
    icon_fullbleed_1024 = Image.new('RGBA', (1024, 1024), (0, 0, 0, 255))
    draw_fb = ImageDraw.Draw(icon_fullbleed_1024)
    draw_fb.text((ix, iy), 'S.', font=font_icon, fill=(255, 255, 255, 255))

    # -------------------------------------------------------------------------
    # E. Generate Multi-Size Branding PNG Variants
    # -------------------------------------------------------------------------
    sizes = [512, 256, 192, 180, 48, 32, 16]
    for s in sizes:
        resized = icon_1024.resize((s, s), Image.Resampling.LANCZOS)
        out_p = os.path.join(branding_dir, f'schoolic-icon-{s}.png')
        resized.save(out_p)
        print(f"Created: assets/branding/schoolic-icon-{s}.png")

    # -------------------------------------------------------------------------
    # F. Windows .ICO Multi-Resolution File (16, 24, 32, 48, 64, 128, 256)
    # -------------------------------------------------------------------------
    ico_path_branding = os.path.join(branding_dir, 'schoolic.ico')
    ico_path_runner = os.path.join(windows_res, 'app_icon.ico')
    icon_1024.save(
        ico_path_branding,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    icon_1024.save(
        ico_path_runner,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    print("Created: assets/branding/schoolic.ico")
    print("Created: windows/runner/resources/app_icon.ico")

    # -------------------------------------------------------------------------
    # G. Web Favicon and PWA Icons
    # -------------------------------------------------------------------------
    # 1. favicon.png (32x32 crisp launcher icon)
    fav_32 = icon_1024.resize((32, 32), Image.Resampling.LANCZOS)
    fav_32.save(os.path.join(web_dir, 'favicon.png'))
    print("Created: web/favicon.png")

    # 2. Standard PWA icons (192 and 512)
    pwa_192 = icon_1024.resize((192, 192), Image.Resampling.LANCZOS)
    pwa_192.save(os.path.join(web_icons_dir, 'Icon-192.png'))
    pwa_512 = icon_1024.resize((512, 512), Image.Resampling.LANCZOS)
    pwa_512.save(os.path.join(web_icons_dir, 'Icon-512.png'))
    print("Created: web/icons/Icon-192.png")
    print("Created: web/icons/Icon-512.png")

    # 3. Maskable PWA icons (192 and 512 full bleed)
    mask_192 = icon_fullbleed_1024.resize((192, 192), Image.Resampling.LANCZOS)
    mask_192.save(os.path.join(web_icons_dir, 'Icon-maskable-192.png'))
    mask_512 = icon_fullbleed_1024.resize((512, 512), Image.Resampling.LANCZOS)
    mask_512.save(os.path.join(web_icons_dir, 'Icon-maskable-512.png'))
    print("Created: web/icons/Icon-maskable-192.png")
    print("Created: web/icons/Icon-maskable-512.png")

    # 4. Apple Touch Icon (180x180 full bleed)
    apple_180 = icon_fullbleed_1024.resize((180, 180), Image.Resampling.LANCZOS)
    apple_180.save(os.path.join(web_icons_dir, 'apple-touch-icon.png'))
    print("Created: web/icons/apple-touch-icon.png")

    # -------------------------------------------------------------------------
    # H. Android Launcher Icons (Mipmaps + Adaptive Icon)
    # -------------------------------------------------------------------------
    android_densities = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, size in android_densities.items():
        dir_path = os.path.join(android_res, folder)
        os.makedirs(dir_path, exist_ok=True)
        img_density = icon_1024.resize((size, size), Image.Resampling.LANCZOS)
        out_density = os.path.join(dir_path, 'ic_launcher.png')
        img_density.save(out_density)
        print(f"Created: android/app/src/main/res/{folder}/ic_launcher.png ({size}x{size})")

    # Android Adaptive Icon: mipmap-anydpi-v26/ic_launcher.xml
    anydpi_dir = os.path.join(android_res, 'mipmap-anydpi-v26')
    os.makedirs(anydpi_dir, exist_ok=True)
    adaptive_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
'''
    with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w') as f:
        f.write(adaptive_xml)
    print("Created: android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml")

    # Android background color: res/values/ic_launcher_background.xml
    values_dir = os.path.join(android_res, 'values')
    os.makedirs(values_dir, exist_ok=True)
    bg_xml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#000000</color>
</resources>
'''
    with open(os.path.join(values_dir, 'ic_launcher_background.xml'), 'w') as f:
        f.write(bg_xml)
    print("Created: android/app/src/main/res/values/ic_launcher_background.xml")

    # Android foreground vector drawable: res/drawable/ic_launcher_foreground.xml
    # 108dp canvas, safe zone central 72dp (from 18 to 90). Center (54, 54).
    # Target width = 52.0dp
    drawable_dir = os.path.join(android_res, 'drawable')
    os.makedirs(drawable_dir, exist_ok=True)
    scale_fg = 52.0 / 810.0
    offset_x_fg = 54.0 - 432.0 * scale_fg
    offset_y_fg = 54.0 + 340.0 * scale_fg
    fg_path = extract_svg_path(font_path, scale=scale_fg, offset_x=offset_x_fg, offset_y=offset_y_fg)

    fg_xml = f'''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="{fg_path}"/>
</vector>
'''
    with open(os.path.join(drawable_dir, 'ic_launcher_foreground.xml'), 'w') as f:
        f.write(fg_xml)
    print("Created: android/app/src/main/res/drawable/ic_launcher_foreground.xml")

    print("\nAll Schoolic official 'S.' branding assets generated successfully!")

if __name__ == '__main__':
    main()
