#!/usr/bin/env python3
"""
Schoolic Official Branding Asset Generator
Implements the Official Schoolic Design System & Logo System:
- Wordmark Lockup: 'Schoolic' with Electric Cyan Square Period (#00A3FF)
- Primary & Reverse Mark: 'S.' with Electric Cyan Square Period (#00A3FF)
- App Icons: Squircle launchers with Electric Cyan Square Period
- Multi-resolution raster and vector exports for Web, Android, Linux, and Windows
"""

import os
import sys
import ctypes
from PIL import Image, ImageDraw, ImageFont

# -----------------------------------------------------------------------------
# 1. FreeType Setup for Exact Vector Extraction
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

def extract_string_svg_path(font_path: str, text: str, scale: float = 1.0, offset_x: float = 0.0, offset_y: float = 0.0):
    """Extracts exact SVG path for a string from font file."""
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

    total_width = 0
    for char in text:
        ft.FT_Load_Char(face, ord(char), 1) # 1 = FT_LOAD_NO_SCALE
        slot = face.contents.glyph.contents
        ft.FT_Outline_Decompose(ctypes.byref(slot.outline), ctypes.byref(funcs), None)
        dx += slot.advance.x
        total_width = dx

    if in_contour:
        d_parts.append('Z')

    return ' '.join(d_parts), total_width

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

    print(f"Generating brand assets from: {font_path}")

    branding_dir = os.path.join(flutter_root, 'assets/branding')
    web_dir = os.path.join(flutter_root, 'web')
    web_icons_dir = os.path.join(web_dir, 'icons')
    android_res = os.path.join(flutter_root, 'android/app/src/main/res')
    windows_res = os.path.join(flutter_root, 'windows/runner/resources')

    os.makedirs(branding_dir, exist_ok=True)
    os.makedirs(web_icons_dir, exist_ok=True)
    os.makedirs(windows_res, exist_ok=True)

    # Brand Colors
    CYAN_HEX = "#00A3FF"
    CYAN_RGB = (0, 163, 255, 255)
    BLACK_HEX = "#111111"
    BLACK_RGB = (17, 17, 17, 255)
    WHITE_HEX = "#FFFFFF"
    WHITE_RGB = (255, 255, 255, 255)

    # -------------------------------------------------------------------------
    # A. Standalone SVG Wordmark: schoolic-logo.svg
    # -------------------------------------------------------------------------
    s_path_mark, s_adv = extract_string_svg_path(font_path, "S", scale=1.0, offset_x=-27.0, offset_y=696.0)
    # S bbox at UPM 1000: xMin=27, xMax=602, yMin=-16, yMax=696, width=575, height=712
    # In Slide 2, Primary Mark:
    # 'S' width = 575, height = 712.
    # Dot is a square of size 145x145, placed at x=610, y=551 (baseline is y=696, dot is from 551 to 696)
    svg_mark_primary = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 780 712" width="780" height="712">
  <path d="{s_path_mark}" fill="{BLACK_HEX}"/>
  <rect x="615" y="551" width="145" height="145" fill="{CYAN_HEX}"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-mark-primary.svg'), 'w') as f:
        f.write(svg_mark_primary)

    svg_mark_reverse = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 780 712" width="780" height="712">
  <path d="{s_path_mark}" fill="{WHITE_HEX}"/>
  <rect x="615" y="551" width="145" height="145" fill="{CYAN_HEX}"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-mark-reverse.svg'), 'w') as f:
        f.write(svg_mark_reverse)

    # Full Wordmark: "Schoolic." in SVG
    word_path, word_adv = extract_string_svg_path(font_path, "Schoolic", scale=1.0, offset_x=-27.0, offset_y=696.0)
    # Word width is word_adv. Dot is square at word_adv + 35, y=551 to 696 (height 145)
    total_svg_w = int((word_adv - 27) + 35 + 145 + 20)
    dot_x_word = int((word_adv - 27) + 35)

    svg_logo = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_svg_w} 712" width="{total_svg_w}" height="712">
  <path d="{word_path}" fill="{BLACK_HEX}"/>
  <rect x="{dot_x_word}" y="551" width="145" height="145" fill="{CYAN_HEX}"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-logo.svg'), 'w') as f:
        f.write(svg_logo)

    svg_logo_white = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total_svg_w} 712" width="{total_svg_w}" height="712">
  <path d="{word_path}" fill="{WHITE_HEX}"/>
  <rect x="{dot_x_word}" y="551" width="145" height="145" fill="{CYAN_HEX}"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-logo-white.svg'), 'w') as f:
        f.write(svg_logo_white)
    print("Created: vector SVG marks and wordmarks with official Cyan Square Period")

    # -------------------------------------------------------------------------
    # B. High-Resolution Raster Wordmarks (Black and White on Transparent)
    # -------------------------------------------------------------------------
    f_wm = ImageFont.truetype(font_path, 320)
    w_bbox = f_wm.getbbox('Schoolic')
    ww = w_bbox[2] - w_bbox[0]
    wh = w_bbox[3] - w_bbox[1]
    dot_sz = int(f_wm.size * 0.17)
    dot_gap = int(dot_sz * 0.4)
    tot_w = ww + dot_gap + dot_sz
    pad = 40

    img_black = Image.new('RGBA', (tot_w + pad * 2, wh + pad * 2), (0, 0, 0, 0))
    img_white = Image.new('RGBA', (tot_w + pad * 2, wh + pad * 2), (0, 0, 0, 0))
    d_black = ImageDraw.Draw(img_black)
    d_white = ImageDraw.Draw(img_white)

    sx = pad - w_bbox[0]
    sy = pad - w_bbox[1]
    baseline = sy + w_bbox[3]
    dx0 = sx + w_bbox[2] + dot_gap
    dy0 = baseline - dot_sz

    d_black.text((sx, sy), 'Schoolic', font=f_wm, fill=BLACK_RGB)
    d_black.rectangle([(dx0, dy0), (dx0 + dot_sz, dy0 + dot_sz)], fill=CYAN_RGB)

    d_white.text((sx, sy), 'Schoolic', font=f_wm, fill=WHITE_RGB)
    d_white.rectangle([(dx0, dy0), (dx0 + dot_sz, dy0 + dot_sz)], fill=CYAN_RGB)

    img_black.save(os.path.join(branding_dir, 'schoolic-logo-black.png'))
    img_white.save(os.path.join(branding_dir, 'schoolic-logo-white.png'))
    print("Created: assets/branding/schoolic-logo-black.png and white.png")

    # -------------------------------------------------------------------------
    # C. Application Icon: 1024x1024 Squircle Master
    # -------------------------------------------------------------------------
    icon_1024 = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    draw_1024 = ImageDraw.Draw(icon_1024)
    draw_1024.rounded_rectangle([(0, 0), (1024, 1024)], radius=225, fill=(0, 0, 0, 255))
    
    font_icon = ImageFont.truetype(font_path, 600)
    bbox_s = font_icon.getbbox('S')
    sw = bbox_s[2] - bbox_s[0]
    sh = bbox_s[3] - bbox_s[1]
    
    dot_icon_sz = int(sw * 0.28)
    dot_icon_gap = int(dot_icon_sz * 0.3)
    icon_content_w = sw + dot_icon_gap + dot_icon_sz
    
    ix = (1024 - icon_content_w) // 2 - bbox_s[0]
    iy = (1024 - sh) // 2 - bbox_s[1]
    
    draw_1024.text((ix, iy), 'S', font=font_icon, fill=WHITE_RGB)
    base_icon = iy + bbox_s[3]
    dot_ix0 = ix + bbox_s[2] + dot_icon_gap
    dot_iy0 = base_icon - dot_icon_sz
    draw_1024.rectangle([(dot_ix0, dot_iy0), (dot_ix0 + dot_icon_sz, dot_iy0 + dot_icon_sz)], fill=CYAN_RGB)
    icon_1024.save(os.path.join(branding_dir, 'schoolic-icon-1024.png'))
    print("Created: assets/branding/schoolic-icon-1024.png")

    # App Icon Vector: schoolic-icon.svg
    scale_icon = sw / 575.0
    scale_svg_icon = 0.65
    offset_x_icon = (1024 - (575 + 145 + 40) * scale_svg_icon) / 2 + 27 * scale_svg_icon
    offset_y_icon = (1024 - 712 * scale_svg_icon) / 2 + 696 * scale_svg_icon
    
    s_path_icon, _ = extract_string_svg_path(font_path, "S", scale=scale_svg_icon, offset_x=offset_x_icon, offset_y=offset_y_icon)
    dot_svg_x = int(offset_x_icon + (575 + 35) * scale_svg_icon)
    dot_svg_y = int(offset_y_icon - 145 * scale_svg_icon)
    dot_svg_sz = int(145 * scale_svg_icon)

    svg_icon = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" rx="225" fill="#000000"/>
  <path d="{s_path_icon}" fill="{WHITE_HEX}"/>
  <rect x="{dot_svg_x}" y="{dot_svg_y}" width="{dot_svg_sz}" height="{dot_svg_sz}" fill="{CYAN_HEX}"/>
</svg>
'''
    with open(os.path.join(branding_dir, 'schoolic-icon.svg'), 'w') as f:
        f.write(svg_icon)
    print("Created: assets/branding/schoolic-icon.svg")

    # Full Bleed Master for maskable icons
    icon_fullbleed_1024 = Image.new('RGBA', (1024, 1024), (0, 0, 0, 255))
    draw_fb = ImageDraw.Draw(icon_fullbleed_1024)
    draw_fb.text((ix, iy), 'S', font=font_icon, fill=WHITE_RGB)
    draw_fb.rectangle([(dot_ix0, dot_iy0), (dot_ix0 + dot_icon_sz, dot_iy0 + dot_icon_sz)], fill=CYAN_RGB)

    # -------------------------------------------------------------------------
    # D. Multi-Size Branding Variants
    # -------------------------------------------------------------------------
    sizes = [512, 256, 192, 180, 48, 32, 16]
    for s in sizes:
        resized = icon_1024.resize((s, s), Image.Resampling.LANCZOS)
        out_p = os.path.join(branding_dir, f'schoolic-icon-{s}.png')
        resized.save(out_p)

    # Windows ICO
    ico_branding = os.path.join(branding_dir, 'schoolic.ico')
    ico_runner = os.path.join(windows_res, 'app_icon.ico')
    icon_1024.save(
        ico_branding,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )
    icon_1024.save(
        ico_runner,
        format='ICO',
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    )

    # Web Favicons & PWA
    fav_32 = icon_1024.resize((32, 32), Image.Resampling.LANCZOS)
    fav_32.save(os.path.join(web_dir, 'favicon.png'))
    fav_32.save(os.path.join(web_dir, 'favicon.ico'))

    icon_1024.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-192.png'))
    icon_1024.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-512.png'))

    icon_fullbleed_1024.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-maskable-192.png'))
    icon_fullbleed_1024.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'Icon-maskable-512.png'))
    icon_fullbleed_1024.resize((180, 180), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, 'apple-touch-icon.png'))

    # Android mipmaps
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
        img_density.save(os.path.join(dir_path, 'ic_launcher.png'))

    print("\nAll Official Schoolic Logo System & App Icons generated successfully!")

if __name__ == '__main__':
    main()
