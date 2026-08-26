# -*- coding: utf-8 -*-
"""生成「绢纸亮色主题」配色示意卡：所有颜色取自 game_ui.gd/premium_ui_art.gd 的实际代码值。
这不是游戏截图——窗口截图在本机暂时不可用(显示子系统卡死)，此卡用于传达两套主题的真实配色。"""
from PIL import Image, ImageDraw, ImageFont
import colorsys

FONT = "C:/Windows/Fonts/msyh.ttc"

def hx(hexstr):
    hexstr = hexstr.lstrip("#")
    return tuple(int(hexstr[i:i+2], 16) / 255.0 for i in (0, 2, 4))

def to_hex(rgb01):
    return tuple(int(round(c * 255)) for c in rgb01)

def text_ink(hexcolor):  # 复刻 _text_color()：浅字转深墨(保留色相)
    r, g, b = hx(hexcolor); h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v < 0.52: return to_hex((r, g, b))
    ink_v = min(max(0.46 - (v - 0.52) * 0.55, 0.16), 0.46)
    s2 = min(max(s * 0.75 + 0.18, 0.0), 0.62)
    return to_hex(colorsys.hsv_to_rgb(h, s2, ink_v))

def panel_paper(hexcolor):  # 复刻 _panel_color()：深底转纸色
    r, g, b = hx(hexcolor); h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v >= 0.62: return to_hex((r, g, b))
    return to_hex(colorsys.hsv_to_rgb(h, min(s * 0.55, 0.30), 0.955))

W, H = 1080, 640
img = Image.new("RGB", (W, H), (24, 22, 18))
d = ImageDraw.Draw(img)
f_title = ImageFont.truetype(FONT, 30)
f_label = ImageFont.truetype(FONT, 17)
f_small = ImageFont.truetype(FONT, 13)
f_btn = ImageFont.truetype(FONT, 16)
f_hero = ImageFont.truetype(FONT, 22)

d.text((W // 2, 34), "主题对比 · 玄墨(现行) vs 绢纸(新增亮色)", font=f_title, fill=(240, 199, 122), anchor="mm")

def vgrad(x0, y0, x1, y1, c0, c1):
    bh = max(1, y1 - y0)
    for i in range(bh):
        t = i / bh
        c = tuple(int(a + (b - a) * t) for a, b in zip(c0, c1))
        d.line([(x0, y0 + i), (x1, y0 + i)], fill=c)

def gloss_button(x0, y0, x1, y1, base_top, base_bottom, ring, gloss_alpha):
    d.rounded_rectangle([x0, y0, x1, y1], radius=12, outline=ring, width=2)
    inner = [x0 + 2, y0 + 2, x1 - 2, y1 - 2]
    mask = Image.new("L", (int(x1 - x0), int(y1 - y0)), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, x1 - x0 - 1, y1 - y0 - 1], radius=11, fill=255)
    bh = int(y1 - y0)
    grad = Image.new("RGB", (int(x1 - x0), bh))
    gd = ImageDraw.Draw(grad)
    for i in range(bh):
        t = i / max(1, bh - 1)
        gd.line([(0, i), (x1 - x0, i)], fill=tuple(int(a + (b - a) * t) for a, b in zip(base_top, base_bottom)))
    gloss = Image.new("L", grad.size, 0)
    gld = ImageDraw.Draw(gloss)
    for i in range(int(bh * 0.45)):
        gld.line([(0, i), (x1 - x0, i)], fill=int(gloss_alpha * (1 - i / (bh * 0.45))))
    white = Image.new("RGB", grad.size, (255, 255, 255))
    grad = Image.composite(white, grad, gloss)
    img.paste(grad.crop((0, 0, int(x1 - x0) - 4, bh - 4)), (int(x0 + 2), int(y0 + 2)), mask.crop((0, 0, int(x1 - x0) - 4, bh - 4)))

def mock(x0, y0, w, h, dark):
    bg0, bg1 = ((hx("#090b0f"), hx("#20130f")) if dark else (hx("#f7f0dc"), hx("#eee2c4")))
    vgrad(x0, y0, x0 + w, y0 + h, to_hex(bg0), to_hex(bg1))
    title_c = to_hex(hx("#f0c77a")) if dark else text_ink("#f0c77a")
    body_c = to_hex(hx("#e8e2cf")) if dark else text_ink("#e8e2cf")
    dim_c = to_hex(hx("#9e8769")) if dark else text_ink("#9e8769")
    btn_top, btn_bot = (to_hex(hx("#39352e")), to_hex(hx("#1c1a16"))) if dark else (to_hex(hx("#fbf5e6")), to_hex(hx("#e2d4b4")))
    ring = to_hex(hx("#d9d2c3")) if dark else to_hex(hx("#8a6a3f"))
    gloss_a = 24 if dark else 76
    panel = to_hex(hx("#12120f")) if dark else panel_paper("#12120f")
    d.text((x0 + w / 2, y0 + 26), "玄墨 · 暗色主题" if dark else "绢纸 · 亮色主题(新)", font=f_label, fill=title_c, anchor="mm")
    # 面板
    px0, py0, px1, py1 = x0 + 28, y0 + 52, x0 + w - 28, y0 + h - 96
    d.rounded_rectangle([px0, py0, px1, py1], radius=10, fill=panel, outline=(142, 103, 61), width=2)
    d.text((px0 + 18, py0 + 24), "江东柱石 · 陆逊", font=f_hero, fill=title_c, anchor="lm")
    d.text((px0 + 18, py0 + 62), "谋定后动，火烧连营。", font=f_label, fill=body_c, anchor="lm")
    d.text((px0 + 18, py0 + 90), "羁绊：四英杰 (2/4)", font=f_small, fill=dim_c, anchor="lm")
    sw = Image.new("RGB", (150, 14)); sd = ImageDraw.Draw(sw)
    sd.rounded_rectangle([0, 0, 149, 13], radius=6, fill=(210, 205, 190) if not dark else (33, 26, 23))
    sd.rounded_rectangle([0, 0, 94, 13], radius=6, fill=(79, 199, 122))
    img.paste(sw, (int(px0 + 18), int(py0 + 112)))
    d.text((px0 + 176, py0 + 119), "72 / 115", font=f_small, fill=body_c, anchor="lm")
    # 按钮
    btn_font = to_hex(hx("#ead9b5")) if dark else to_hex(hx("#4a3d26"))
    gloss_button(px0 + 18, py1 - 56, px0 + 158, py1 - 14, btn_top, btn_bot, ring, gloss_a)
    d.text((px0 + 88, py1 - 35), "上 阵", font=f_btn, fill=btn_font, anchor="mm")
    # 强调按钮
    acc = (200, 176, 138) if dark else (240, 220, 180)
    gloss_button(px0 + 178, py1 - 56, px0 + 318, py1 - 14, tuple(int(a * 0.55 + b * 0.45) for a, b in zip(btn_top, (185, 138, 79))), tuple(int(a * 0.55 + b * 0.45) for a, b in zip(btn_bot, (185, 138, 79))), ring, gloss_a)
    d.text((px0 + 248, py1 - 35), "出 征", font=f_btn, fill=(60, 40, 12) if not dark else (255, 240, 200), anchor="mm")
    # 底部页签示意
    ty = y0 + h - 52
    if dark:
        d.rounded_rectangle([x0 + 28, ty, x0 + 108, ty + 30], radius=7, fill=(38, 32, 20), outline=(212, 168, 95), width=2)
    else:
        d.rounded_rectangle([x0 + 28, ty, x0 + 108, ty + 30], radius=7, fill=(253, 247, 232), outline=(160, 108, 34), width=2)
    d.text((x0 + 68, ty + 15), "武将图鉴", font=f_small, fill=title_c, anchor="mm")
    d.rounded_rectangle([x0 + 116, ty, x0 + 196, ty + 30], radius=7, outline=(143, 122, 82) if not dark else (69, 58, 38), width=1)
    d.text((x0 + 156, ty + 15), "武器图鉴", font=f_small, fill=dim_c, anchor="mm")

mock(40, 70, 490, 470, True)
mock(550, 70, 490, 470, False)

# 底部色板
swatches = [
    ("纸面渐变", to_hex(hx("#f7f0dc"))), ("面板纸色", panel_paper("#12120f")), ("遮罩纸色", (244, 238, 220)),
    ("按钮面", to_hex(hx("#e2d4b4"))), ("描边金", to_hex(hx("#8e673d"))), ("标题墨金", text_ink("#f0c77a")),
    ("正文墨", text_ink("#e8e2cf")), ("弱化墨", text_ink("#9e8769")),
]
sx = 60
for name, c in swatches:
    d.rounded_rectangle([sx, 566, sx + 108, 600], radius=8, fill=c, outline=(90, 74, 50), width=1)
    d.text((sx + 54, 612), name, font=f_small, fill=(220, 205, 175), anchor="mm")
    sx += 122
d.text((W - 24, 626), "配色示意卡 · 全部取自代码实际颜色值(非游戏截图) · 游戏内:设置→主题切换", font=f_small, fill=(150, 135, 105), anchor="rm")

img.save("test/light_theme_preview.png")
print("saved test/light_theme_preview.png")
