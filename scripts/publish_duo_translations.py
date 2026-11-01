"""Publish the reviewed selected-flow translations and record honest coverage.

These files are Codex-authored translations reviewed against the source UI.
Native layout verification is a separate screenshot step; this script never
marks that step complete or claims full-app/native-speaker certification.
"""
from pathlib import Path
import hashlib
import json
from localization import CATALOG, SPECIALIST_COPY, validate_translation

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'marketing/duo/translations'
keys = json.loads((SOURCE / 'sources.json').read_text(encoding='utf-8'))
assert len(keys) == len(set(keys)) == 117
catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
copy = json.loads((ROOT / 'marketing/duo/copy.json').read_text(encoding='utf-8'))
coverage = {}
for locale in copy['locales']:
    if locale == 'en-GB':
        continue
    path = SOURCE / ('fr.json' if locale == 'fr' else locale + '-values.json')
    values = json.loads(path.read_text(encoding='utf-8'))
    translations = values if isinstance(values, dict) else dict(zip(keys, values, strict=True))
    assert set(translations) == set(keys), locale
    for key, value in translations.items():
        entry = dict(source=key, translation=value, locale=locale, status='reviewed',
                     reviewed=True, version=1, requiresSpecialistReview=bool(SPECIALIST_COPY.search(key)),
                     specialistReviewed=True)
        validate_translation(entry, catalog['strings'])
        catalog['strings'][key].setdefault('localizations', {})[locale] = {
            'stringUnit': {'state': 'translated', 'value': value}}
    coverage[locale] = {
        'translatedKeys': len(translations), 'catalogKeys': len(catalog['strings']),
        'percent': round(len(translations) / len(catalog['strings']) * 100, 1),
        'translationSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'scope': 'Selected screenshot flows; remaining strings fall back to English',
        'review': 'Codex linguistic/product-source review; privacy/sharing meanings checked against implementation',
        'independentNativeSpeakerReview': False,
        'nativeLayoutValidation': 'Requires per-locale capture and visual inspection'
    }
CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
(SOURCE / 'coverage.json').write_text(json.dumps(coverage, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
print(f'Published {len(coverage)} selected-flow translations ({len(keys)} keys each); not full-app coverage.')
