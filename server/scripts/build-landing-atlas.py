# Bakes every cover in public/books.js into one same-origin WebP atlas for the landing page's WebGL hero
# (the covers are cross-origin without CORS, so WebGL can't read them directly).
# Usage: python3 scripts/build-landing-atlas.py public/books.js public/covers-atlas.webp > /tmp/books.js && mv /tmp/books.js public/books.js
import json, sys, io, urllib.request
from PIL import Image
src_path, out_img = sys.argv[1], sys.argv[2]
src = open(src_path).read()
books = json.loads(src[src.index('['):src.rindex(']')+1])
COLS, SW, SH = 8, 272, 400   # slot size; the cover is stretched to fill the slot, so mip bleed only repeats its own edge
rows = (len(books) + COLS - 1) // COLS
atlas = Image.new('RGB', (COLS*SW, rows*SH), (200, 196, 190))
for i, b in enumerate(books):
    req = urllib.request.Request(b['cover'], headers={'User-Agent': 'Mozilla/5.0'})
    im = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=30).read())).convert('RGB')
    w, h = im.size
    # centre-crop to 2:3
    if h / w > 1.5: nh = int(w*1.5); im = im.crop((0, (h-nh)//2, w, (h-nh)//2+nh))
    else: nw = int(h/1.5); im = im.crop(((w-nw)//2, 0, (w-nw)//2+nw, h))
    atlas.paste(im.resize((SW, SH), Image.LANCZOS), ((i % COLS)*SW, (i // COLS)*SH))
    b['slot'] = i
atlas.save(out_img, 'WEBP', quality=80, method=6)
print('window.BB_ATLAS = ' + json.dumps({'src': '/' + out_img.split('/')[-1], 'cols': COLS, 'rows': rows, 'slotW': SW, 'slotH': SH}) + ';')
print('window.BB_BOOKS = ' + json.dumps(books, ensure_ascii=False) + ';')
