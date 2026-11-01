"""Download and verify successful native locale artifacts without rerendering UI."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageStat
from capture_duo import REGIONS

ROOT = Path(__file__).resolve().parents[1]
COPY = json.loads((ROOT / 'marketing/duo/copy.json').read_text(encoding='utf-8'))

def gh(*args):
    return subprocess.run(['gh', *args], check=True, capture_output=True, text=True).stdout

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True, type=int)
    parser.add_argument('--available', action='store_true', help='Collect finished locales while other jobs run')
    options = parser.parse_args()
    assert options.run > 0
    repo = 'lanray07/LeaveWell'
    response = json.loads(gh('api', f'repos/{repo}/actions/runs/{options.run}/artifacts?per_page=100'))
    artifacts = {a['name']: a for a in response['artifacts'] if not a['expired']}
    dest = ROOT / 'marketing/duo/captures'
    downloads = ROOT / 'build/duo-downloads' / str(options.run)
    rows = []
    sources = {}
    missing = []
    for locale in COPY['locales']:
        name = 'Duo-' + locale
        if name not in artifacts:
            missing.append(locale)
            continue
        folder = downloads / name
        if not (folder / 'manifest.json').exists():
            folder.mkdir(parents=True, exist_ok=True)
            gh('run', 'download', str(options.run), '--repo', repo, '--name', name, '--dir', str(folder))
        manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
        captures = manifest['captures']
        assert len(captures) == 10 and {c['route'] for c in captures} == set(COPY['routes']), locale
        sources[locale] = {key: manifest[key] for key in ['sourceCommit', 'sourceSDK']}
        for record in captures:
            assert record['locale'] == record['bundleLocale'] == locale, record
            assert record['family'] == 'outer'
            assert record['foundationLocale'] == REGIONS[locale], record
            relative = Path(record['file'])
            assert relative.parts[:2] == (locale, 'outer') and '..' not in relative.parts
            source = (folder / relative).resolve()
            assert source.is_relative_to(folder.resolve())
            assert hashlib.sha256(source.read_bytes()).hexdigest() == record['sha256'], source
            with Image.open(source) as image:
                assert image.size == (1398, 2034), source
                assert max(ImageStat.Stat(image.convert('RGB').resize((80, 80))).stddev) > 10, source
            target = dest / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            rows.append(record)
    if missing and not options.available:
        raise SystemExit('Native locales still missing: ' + ', '.join(missing))
    assert rows, 'No complete native locale artifacts available yet'
    result = dict(status='complete' if not missing else 'partial',
                  sourceRun=f'https://github.com/{repo}/actions/runs/{options.run}',
                  captures=rows, sources=sources, missingLocales=missing,
                  innerDisplay='Not captured; prior black frames rejected')
    (dest / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Collected {len(rows)} verified native images across {len(sources)} locales; {len(missing)} locales pending.')

if __name__ == '__main__':
    main()
