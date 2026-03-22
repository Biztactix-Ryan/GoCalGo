#!/usr/bin/env python3
"""Generate the GoCalGo app icon at 1024x1024.

Design: A calendar icon with a Pokeball-inspired color scheme.
- Rounded square background with a gradient from red (#EE1515) to dark red (#CC0000)
- White calendar page element in the center
- A simplified Pokeball circle motif on the calendar
- "Go" text to tie it to Pokemon Go
"""

from PIL import Image, ImageDraw, ImageFont
import math

SIZE = 1024
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background - Pokemon red gradient effect
# Fill with base red, then overlay a darker bottom
for y in range(SIZE):
    ratio = y / SIZE
    r = int(238 - ratio * 40)  # 238 -> 198
    g = int(21 - ratio * 15)   # 21 -> 6
    b = int(21 - ratio * 15)   # 21 -> 6
    draw.line([(0, y), (SIZE - 1, y)], fill=(r, g, b, 255))

# Round the corners by masking
mask = Image.new("L", (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
corner_radius = 180
mask_draw.rounded_rectangle([(0, 0), (SIZE - 1, SIZE - 1)], radius=corner_radius, fill=255)
img.putalpha(mask)

# Calendar page - white rounded rectangle
cal_margin = 180
cal_top = 200
cal_bottom = SIZE - 160
cal_left = cal_margin
cal_right = SIZE - cal_margin
draw.rounded_rectangle(
    [(cal_left, cal_top), (cal_right, cal_bottom)],
    radius=40,
    fill=(255, 255, 255, 240),
)

# Calendar top bar (darker red strip)
bar_height = 70
draw.rounded_rectangle(
    [(cal_left, cal_top), (cal_right, cal_top + bar_height + 20)],
    radius=40,
    fill=(180, 0, 0, 255),
)
# Flatten bottom corners of bar
draw.rectangle(
    [(cal_left, cal_top + 40), (cal_right, cal_top + bar_height + 20)],
    fill=(180, 0, 0, 255),
)

# Calendar binding dots on the bar
dot_radius = 16
dot_y = cal_top + bar_height // 2
for dx in [-120, -40, 40, 120]:
    cx = SIZE // 2 + dx
    draw.ellipse(
        [(cx - dot_radius, dot_y - dot_radius), (cx + dot_radius, dot_y + dot_radius)],
        fill=(255, 255, 255, 200),
    )

# Pokeball motif in the calendar body
ball_cx = SIZE // 2
ball_cy = (cal_top + bar_height + 20 + cal_bottom) // 2 + 10
ball_r = 130

# Top half - red
draw.pieslice(
    [(ball_cx - ball_r, ball_cy - ball_r), (ball_cx + ball_r, ball_cy + ball_r)],
    start=180,
    end=360,
    fill=(238, 21, 21, 255),
)
# Bottom half - white
draw.pieslice(
    [(ball_cx - ball_r, ball_cy - ball_r), (ball_cx + ball_r, ball_cy + ball_r)],
    start=0,
    end=180,
    fill=(240, 240, 240, 255),
)
# Center band - dark line
band_h = 12
draw.rectangle(
    [(ball_cx - ball_r, ball_cy - band_h // 2), (ball_cx + ball_r, ball_cy + band_h // 2)],
    fill=(60, 60, 60, 255),
)
# Center circle - outer
center_r = 36
draw.ellipse(
    [(ball_cx - center_r, ball_cy - center_r), (ball_cx + center_r, ball_cy + center_r)],
    fill=(60, 60, 60, 255),
)
# Center circle - inner (white button)
inner_r = 22
draw.ellipse(
    [(ball_cx - inner_r, ball_cy - inner_r), (ball_cx + inner_r, ball_cy + inner_r)],
    fill=(255, 255, 255, 255),
)

# "GoCalGo" text at the very top
try:
    font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72)
    font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36)
except OSError:
    font_large = ImageFont.load_default()
    font_small = ImageFont.load_default()

# App name at the top
text = "GoCalGo"
bbox = draw.textbbox((0, 0), text, font=font_large)
tw = bbox[2] - bbox[0]
draw.text(
    ((SIZE - tw) // 2, 90),
    text,
    fill=(255, 255, 255, 255),
    font=font_large,
)

# Save the main icon
output_path = "/p/gocalgo/src/app/assets/icons/app_icon.png"
img.save(output_path, "PNG")
print(f"Icon saved to {output_path}")

# Also save the adaptive icon foreground (with transparent padding for Android adaptive)
# Android adaptive icons use a 108dp canvas with 72dp safe zone (inner 66.67%)
adaptive_size = 1024
adaptive = Image.new("RGBA", (adaptive_size, adaptive_size), (0, 0, 0, 0))
# Scale the content to fit within the safe zone (66.67% of canvas)
safe_zone = int(adaptive_size * 0.667)
offset = (adaptive_size - safe_zone) // 2

# Create a version without rounded corners for the foreground
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fg_draw = ImageDraw.Draw(fg)

# Pokeball on transparent background for foreground
# Calendar page
fg_draw.rounded_rectangle(
    [(cal_left, cal_top), (cal_right, cal_bottom)],
    radius=40,
    fill=(255, 255, 255, 240),
)
# Calendar bar
fg_draw.rounded_rectangle(
    [(cal_left, cal_top), (cal_right, cal_top + bar_height + 20)],
    radius=40,
    fill=(180, 0, 0, 255),
)
fg_draw.rectangle(
    [(cal_left, cal_top + 40), (cal_right, cal_top + bar_height + 20)],
    fill=(180, 0, 0, 255),
)
# Dots
for dx in [-120, -40, 40, 120]:
    cx = SIZE // 2 + dx
    fg_draw.ellipse(
        [(cx - dot_radius, dot_y - dot_radius), (cx + dot_radius, dot_y + dot_radius)],
        fill=(255, 255, 255, 200),
    )
# Pokeball
fg_draw.pieslice(
    [(ball_cx - ball_r, ball_cy - ball_r), (ball_cx + ball_r, ball_cy + ball_r)],
    start=180, end=360, fill=(238, 21, 21, 255),
)
fg_draw.pieslice(
    [(ball_cx - ball_r, ball_cy - ball_r), (ball_cx + ball_r, ball_cy + ball_r)],
    start=0, end=180, fill=(240, 240, 240, 255),
)
fg_draw.rectangle(
    [(ball_cx - ball_r, ball_cy - band_h // 2), (ball_cx + ball_r, ball_cy + band_h // 2)],
    fill=(60, 60, 60, 255),
)
fg_draw.ellipse(
    [(ball_cx - center_r, ball_cy - center_r), (ball_cx + center_r, ball_cy + center_r)],
    fill=(60, 60, 60, 255),
)
fg_draw.ellipse(
    [(ball_cx - inner_r, ball_cy - inner_r), (ball_cx + inner_r, ball_cy + inner_r)],
    fill=(255, 255, 255, 255),
)
# Text
try:
    fg_draw.text(
        ((SIZE - tw) // 2, 90),
        text,
        fill=(255, 255, 255, 255),
        font=font_large,
    )
except:
    pass

# Resize and center in adaptive canvas
fg_resized = fg.resize((safe_zone, safe_zone), Image.LANCZOS)
adaptive.paste(fg_resized, (offset, offset), fg_resized)

adaptive_path = "/p/gocalgo/src/app/assets/icons/app_icon_adaptive_foreground.png"
adaptive.save(adaptive_path, "PNG")
print(f"Adaptive foreground saved to {adaptive_path}")

# Adaptive background - solid red
bg = Image.new("RGBA", (1024, 1024), (238, 21, 21, 255))
bg_path = "/p/gocalgo/src/app/assets/icons/app_icon_adaptive_background.png"
bg.save(bg_path, "PNG")
print(f"Adaptive background saved to {bg_path}")

print("Done! All icon assets generated.")
