"""Maintain English String Catalog entries and gate reviewed translations.

No translation API is contacted. Drafts live outside app resources.
Usage: python scripts/localization.py [--check | --publish reviewed.json]
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SUPPORTED = ['en-GB', 'en-US', 'es', 'fr', 'de', 'it', 'pt', 'nl', 'pl', 'ro', 'ar', 'hi', 'zh-Hans', 'zh-Hant', 'ja', 'ko']
CATALOG = ROOT / 'LeaveWell/Resources/Localizable.xcstrings'

SPECIALIST_COPY = re.compile(r'privacy|private|legal|liability|dispute|deposit|timestamp|hash|sharing|share|delete|deletion|cloud|backup|backups|original|passcode|Face ID|device protection|declaration|best of my knowledge', re.I)

def validate_translation(entry, known_keys):
    required = {'source', 'translation', 'locale', 'status', 'reviewed', 'version', 'requiresSpecialistReview'}
    if not required.issubset(entry): raise ValueError('Translation metadata is incomplete.')
    if entry['locale'] not in SUPPORTED: raise ValueError('Unsupported locale.')
    if entry['source'] not in known_keys: raise ValueError('Unknown source key.')
    if not isinstance(entry['translation'], str) or not entry['translation'].strip(): raise ValueError('Empty translation.')
    if entry['status'] != 'reviewed' or entry['reviewed'] is not True: raise ValueError('Only reviewed translations may be published.')
    # A draft provider cannot downgrade sensitive copy by setting its own flag to false.
    specialist_required = entry['requiresSpecialistReview'] or bool(SPECIALIST_COPY.search(entry['source']))
    if specialist_required and entry.get('specialistReviewed') is not True: raise ValueError('Specialist review is required.')
    if entry['version'] != 1: raise ValueError('Source version mismatch.')

def sources():
    found = set()
    for file in (ROOT / 'LeaveWell').rglob('*.swift'):
        text = file.read_text(encoding='utf-8')
        # Include static literals passed indirectly through L (plans, guides, enum labels).
        for raw in re.findall(r'"((?:[^"\\]|\\.)*)"', text):
            if '\\(' in raw or '/' in raw and raw.startswith('originals/'):
                continue
            try:
                value = json.loads('"' + raw + '"')
            except ValueError:
                continue
            if value and re.search(r'[A-Za-z]', value) and ((' ' in value or value[0].isupper()) and not value.startswith(('LW-', 'EV-', 'GB-', 'SHA-'))):
                found.add(value)
    return found

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); parser.add_argument('--publish', type=Path)
    args = parser.parse_args()
    catalog = json.loads(CATALOG.read_text(encoding='utf-8')) if CATALOG.exists() else {'sourceLanguage': 'en-GB', 'strings': {}, 'version': '1.0'}
    missing = sources() - catalog['strings'].keys()
    if args.check:
        if missing:
            raise SystemExit('Missing catalog keys: ' + ', '.join(sorted(missing)))
        for key, entry in catalog['strings'].items():
            for locale, translated in entry.get('localizations', {}).items():
                if translated['stringUnit']['state'] != 'translated':
                    raise SystemExit(f'Unreviewed translation bundled: {locale}: {key}')
        print(f'Catalog valid: {len(catalog["strings"])} English keys; unpublished languages fall back to English.')
        return
    for key in sorted(missing):
        catalog['strings'][key] = {'extractionState': 'manual', 'localizations': {'en-GB': {'stringUnit': {'state': 'translated', 'value': key}}}}
    if args.publish:
        for entry in json.loads(args.publish.read_text(encoding='utf-8')):
            try: validate_translation(entry, catalog['strings'])
            except ValueError as error: raise SystemExit(str(error))
            catalog['strings'][entry['source']].setdefault('localizations', {})[entry['locale']] = {'stringUnit': {'state': 'translated', 'value': entry['translation']}}
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    print(f'Updated catalog: {len(catalog["strings"])} keys.')

if __name__ == '__main__': main()
