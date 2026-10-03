"""Deterministic App Store typography and export around unaltered real UI captures."""
from pathlib import Path
import hashlib
import json
import argparse
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'marketing/exports'
SOURCE = ROOT / 'marketing/source'
FONT = Path('C:/Windows/Fonts')
CREAM = '#F5F2E9'
TEAL = '#153F3E'
MUTED = '#466561'
STORY = [
    ('home', ['Moving out?', "You've got this."], 'Your rental checkout, one calm step at a time.', 'lifestyle-home', False, 'MOVE-OUT CHECKLIST'),
    ('room', ['Photo evidence.', 'Room by room.'], 'From the whole room to the small details.', 'demo-kitchen', True, 'GUIDED ROOM RECORDS'),
    ('evidence', ['Your rental records.', 'All together.'], 'Find photos, notes and supporting files.', 'demo-kitchen', False, 'PROPERTY EVIDENCE'),
    ('notes', ['The little details', 'deserve a note.'], 'Write what you observed while it is fresh.', 'subscription-organised', False, 'FACTUAL CONDITION NOTES'),
    ('meters', ['Final meter readings.', 'Clearly recorded.'], 'Save the digits. Check the details yourself.', None, True, 'ELECTRICITY Â· GAS Â· WATER'),
    ('keys', ['Keys handed over.', 'Details kept.'], 'Record quantities, recipients and dates.', 'lifestyle-keys', False, 'KEY & FOB HANDOVER'),
    ('documents', ['Inventory. Receipts.', 'One document vault.'], 'Keep the paperwork with your move.', 'subscription-organised', False, 'RENTAL DOCUMENTS'),
    ('comparison', ['Move-in to move-out.', 'Make your own notes.'], 'Review your inventory and current evidence.', 'demo-kitchen', True, 'INVENTORY COMPARISON'),
    ('plan', ['A calmer move-out', 'starts with a plan.'], 'A dated checklist you can work through.', 'lifestyle-home', False, 'TENANT MOVE-OUT PLAN'),
    ('report', ['An evidence report', 'you can share.'], 'Create unlimited PDF reports with LeaveWell Plus.', 'subscription-next-chapter', True, 'PDF REPORTS · PAID SUBSCRIPTION'),
]

def font(size, bold=False):
    return ImageFont.truetype(str(FONT / ('segoeuib.ttf' if bold else 'segoeui.ttf')), size)

def fitted(draw, lines, max_width, size=100):
    while max(draw.textlength(line, font=font(size, True)) for line in lines) > max_width:
        size -= 1
    return font(size, True), size

def wrapped(draw, text, face, width):
    lines = ['']
    for word in text.split():
        trial = (lines[-1] + ' ' + word).strip()
        if draw.textlength(trial, font=face) <= width: lines[-1] = trial
        else: lines.append(word)
    return lines

def photo_panel(canvas, name, box, radius):
    if name is None: return
    x, y, width, height = box
    original = Image.open(SOURCE / (name + '.png')).convert('RGB')
    photo = ImageOps.fit(original, (width, height), method=Image.Resampling.LANCZOS, centering=(0.82, 0.62))
    mask = Image.new('L', (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width-1, height-1), radius=radius, fill=255)
    canvas.paste(photo, (x, y), mask)

def phone(canvas, capture, box, corner=0.095):
    x, y, width = box
    screen = Image.open(capture).convert('RGB')
    height = round(width * screen.height / screen.width)
    screen = screen.resize((width, height), Image.Resampling.LANCZOS)
    radius = round(width * corner)
    shadow = Image.new('RGBA', canvas.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x-14, y+12, x+width+14, y+height+30), radius=radius+14, fill=(0, 15, 15, 65))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
    ImageDraw.Draw(canvas).rounded_rectangle((x-12, y-12, x+width+12, y+height+12), radius=radius+12, fill='#242C2C', outline='#788480', width=3)
    mask = Image.new('L', screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width-1, height-1), radius=radius, fill=255)
    canvas.paste(screen, (x, y), mask)
    # Capture remains exact; only the physical frame and corner mask are added.
    return height

def export_iphone(raw):
    out = DEST / 'iphone-6.5'; out.mkdir(parents=True, exist_ok=True)
    for index, (route, headlines, subtitle, photo, dark, kicker) in enumerate(STORY, 1):
        canvas = Image.new('RGBA', (1284, 2778), TEAL if dark else CREAM)
        draw = ImageDraw.Draw(canvas)
        foreground = CREAM if dark else TEAL
        secondary = '#CBDAD4' if dark else MUTED
        draw.text((82, 74), 'LEAVEWELL', font=font(34, True), fill=foreground)
        draw.line((82, 147, 1202, 147), fill='#3F6560' if dark else '#D5DED5', width=2)
        draw.text((82, 190), kicker, font=font(28, True), fill=secondary)
        headline_font, size = fitted(draw, headlines, 1120)
        for row, text in enumerate(headlines): draw.text((76, 267+row*(size+22)), text, font=headline_font, fill=foreground)
        for row, line in enumerate(wrapped(draw, subtitle, font(37), 1100)): draw.text((82, 533+row*55), line, font=font(37), fill=secondary)
        if photo:
            photo_panel(canvas, photo, (735, 735, 466, 1830), 62)
            phone(canvas, raw / f'{index:02d}-{route}.png', (87, 755, 830))
        else:
            draw.rounded_rectangle((720, 755, 1204, 2570), radius=62, fill='#315D58')
            draw.text((973, 1830), 'CHECKED', font=font(26, True), fill=CREAM, anchor='mm')
            draw.text((973, 1880), 'BY YOU', font=font(26, True), fill=CREAM, anchor='mm')
            phone(canvas, raw / f'{index:02d}-{route}.png', (87, 755, 830))
        draw = ImageDraw.Draw(canvas)
        draw.text((82, 2670), 'Real app views Â· Fictional demo records', font=font(26), fill=secondary)
        draw.text((1202, 2670), f'{index:02d} / 10', font=font(26), fill=secondary, anchor='ra')
        canvas.convert('RGB').save(out / f'{index:02d}-{route}.png', optimize=True)

def export_ipad(raw):
    out = DEST / 'ipad-13'; out.mkdir(parents=True, exist_ok=True)
    for index, (route, headlines, subtitle, photo, dark, kicker) in enumerate(STORY, 1):
        canvas = Image.new('RGBA', (2064, 2752), TEAL if dark else CREAM)
        draw = ImageDraw.Draw(canvas)
        fg = CREAM if dark else TEAL; sub = '#CBDAD4' if dark else MUTED
        draw.text((122, 82), 'LEAVEWELL Â· ' + kicker, font=font(35, True), fill=sub)
        face, size = fitted(draw, headlines, 1820, 118)
        for row, line in enumerate(headlines): draw.text((112, 180+row*(size+18)), line, font=face, fill=fg)
        draw.text((122, 493), subtitle, font=font(46), fill=sub)
        if photo: photo_panel(canvas, photo, (1250, 700, 690, 1770), 80)
        # Tablet screenshots retain their native layout and aspect ratio.
        phone(canvas, raw / f'{index:02d}-{route}.png', (124, 692, 1360), corner=0.04)
        draw = ImageDraw.Draw(canvas)
        draw.text((122, 2620), 'Real app views Â· Fictional demo records', font=font(34), fill=sub)
        draw.text((1942, 2620), f'{index:02d} / 10', font=font(34), fill=sub, anchor='ra')
        canvas.convert('RGB').save(out / f'{index:02d}-{route}.png', optimize=True)

def subscriptions():
    out = DEST / 'subscriptions'; out.mkdir(parents=True, exist_ok=True)
    for name in ['subscription-organised', 'subscription-next-chapter']:
        # Promotional imagery is separate from the actual StoreKit purchase-review screenshot.
        image = Image.open(SOURCE / (name + '.png')).convert('RGB')
        ImageOps.fit(image, (1024, 1024), method=Image.Resampling.LANCZOS).save(out / (name + '.png'), optimize=True)

def manifest():
    items = []
    for path in sorted(DEST.rglob('*.png')):
        if path.name == 'preview.png': continue
        with Image.open(path) as image:
            items.append({'file': path.relative_to(ROOT).as_posix(), 'width': image.width, 'height': image.height, 'mode': image.mode, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (DEST / 'manifest.json').write_text(json.dumps({'generation': 'Built-in ImageGen for lifestyle photography; real GitHub iOS Simulator captures; deterministic Pillow copy and export', 'fictionalDemoData': True, 'assets': items}, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--raw', type=Path); args = parser.parse_args()
    if args.raw:
        if (args.raw / 'iphone').exists(): export_iphone(args.raw / 'iphone')
        if (args.raw / 'ipad').exists(): export_ipad(args.raw / 'ipad')
    subscriptions(); manifest()
    print('Exported App Store images to', DEST)
