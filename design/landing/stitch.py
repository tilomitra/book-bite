#!/usr/bin/env python3
"""Joins the frames from testCaptureWalkthrough (each drag scrolls the page 772 px) into one tall screen for the
landing page's walkthrough, plus the fixed top and tab bar layers that sit over it inside the phone."""
from pathlib import Path
from PIL import Image

here = Path(__file__).parent
raw, out = here / 'raw', here.parent.parent / 'server/public/screens'
STEP, FROM, TO = 772, 1000, 1772  # the middle of each frame, clear of both bars
W = 840

def stitch(name, frames, top_end):
    ims = [Image.open(raw / f'{name}-{i}.png').convert('RGB') for i in range(frames)]
    sheet = Image.new('RGB', (1320, TO + STEP * (frames - 1) + 1096))
    sheet.paste(ims[0].crop((0, 0, 1320, TO)), (0, 0))
    for i in range(1, frames):
        sheet.paste(ims[i].crop((0, FROM, 1320, TO)), (0, FROM + STEP * i))
    sheet.paste(ims[-1].crop((0, FROM, 1320, 2868)), (0, FROM + STEP * (frames - 1)))
    sheet.resize((W, round(sheet.height * W / 1320)), Image.LANCZOS).save(out / f'{name}-tall.webp', quality=78, method=6)

    # The top: status bar (and the book page's buttons), fading out at its lower edge
    top = ims[0].crop((0, 0, 1320, top_end)).convert('RGBA')
    fade = Image.new('L', (1, top_end), 255)
    for y in range(top_end - 44, top_end):
        fade.putpixel((0, y), round(255 * (top_end - y) / 44))
    top.putalpha(fade.resize(top.size))
    top.resize((W, round(top_end * W / 1320)), Image.LANCZOS).save(out / f'{name}-top.webp', quality=86, method=6)
    print(name, sheet.size)

stitch('discover', 6, 190)
stitch('detail', 6, 340)
