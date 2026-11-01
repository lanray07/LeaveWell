"""Capture ten production flows with fictional records on native iPhone Duo.

The ephemeral simulator is owned by this workflow. Each job uses one locale and
fresh install. No physical-device records or account credentials are accessed.
"""
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY = json.loads((ROOT / 'marketing/duo/copy.json').read_text(encoding='utf-8'))
REGIONS = {'en-GB': 'en_GB', 'fr': 'fr_FR', 'es': 'es_ES', 'de': 'de_DE', 'it': 'it_IT',
           'pt-BR': 'pt_BR', 'nl': 'nl_NL', 'pl': 'pl_PL', 'ar': 'ar_SA', 'hi': 'hi_IN',
           'ja': 'ja_JP', 'ko': 'ko_KR', 'zh-Hans': 'zh_CN', 'zh-Hant': 'zh_TW',
           'tr': 'tr_TR', 'id': 'id_ID', 'sv': 'sv_SE'}
assert set(REGIONS) == set(COPY['locales'])

def run(*args, check=True, timeout=180):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        print(result.stdout, result.stderr, flush=True)
        result.check_returncode()
    return result.stdout.strip()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--locale', choices=COPY['locales'], required=True)
    parser.add_argument('--app', type=Path, default=Path('build/LeaveWell.app'))
    parser.add_argument('--out', type=Path, default=Path('build/DuoRaw'))
    options = parser.parse_args()
    locale = options.locale
    if locale == 'en-GB':
        expected_kitchen = 'Kitchen'
    elif locale == 'fr':
        expected_kitchen = json.loads((ROOT / 'marketing/duo/translations/fr.json').read_text(encoding='utf-8'))['Kitchen']
    else:
        expected_kitchen = json.loads((ROOT / f'marketing/duo/translations/{locale}-values.json').read_text(encoding='utf-8'))[12]
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
    device = next(d for runtime, group in devices.items() if runtime.endswith('iOS-27-1')
                  for d in group if d['name'] == 'iPhone Duo')
    udid = device['udid']
    run('xcrun', 'simctl', 'boot', udid, check=False)
    run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=600)
    screens = run('xcrun', 'simctl', 'io', udid, 'enumerate')
    screen_id = None
    for block in re.split(r'(?=\(\d+\) [^\n]+:)', screens):
        if 'Screen Type: Integrated' in block and 'Pixel Size: {1398, 2034}' in block:
            screen_id = re.search(r'Screen ID: (\d+)', block)[1]
    assert screen_id, 'No native Duo outer display found'
    run('xcrun', 'simctl', 'ui', udid, 'appearance', 'light')
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41',
        '--batteryState', 'charged', '--batteryLevel', '100')
    run('xcrun', 'simctl', 'install', udid, str(options.app))
    container = Path(run('xcrun', 'simctl', 'get_app_container', udid, 'com.leavewell.app', 'data'))
    destination = options.out / locale / 'outer'
    destination.mkdir(parents=True, exist_ok=True)
    captures = []
    for index, route in enumerate(COPY['routes'], 1):
        run('xcrun', 'simctl', 'terminate', udid, 'com.leavewell.app', check=False)
        marker = container / ('Documents/MarketingReady-' + route)
        marker.unlink(missing_ok=True)
        run('xcrun', 'simctl', 'launch', udid, 'com.leavewell.app', '-marketing-route', route,
            '-AppleLanguages', '("' + locale + '")', '-AppleLocale', REGIONS[locale])
        for attempt in range(90):
            if marker.exists():
                break
            time.sleep(1)
        else:
            raise RuntimeError('App did not prepare ' + route)
        ready = json.loads(marker.read_text())
        assert ready['bundleLocale'] == locale, ready
        assert ready['sampleKitchen'] == expected_kitchen, ready
        time.sleep(3)
        path = destination / f'{index:02d}-{route}.png'
        run('xcrun', 'simctl', 'io', udid, 'screenshot', '--display=' + screen_id, str(path))
        run('build/audit-native-capture', str(path))
        captures.append(dict(locale=locale, bundleLocale=ready['bundleLocale'],
                             foundationLocale=ready['locale'], family='outer', route=route,
                             file=path.relative_to(options.out).as_posix(),
                             sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        print('Captured and validated', locale, route, flush=True)
    source_commit = run('git', 'rev-parse', 'HEAD')
    options.out.joinpath('manifest.json').write_text(json.dumps(dict(sourceCommit=source_commit,
        sourceSDK='Xcode 27.1 / iOS 27.1', captures=captures), ensure_ascii=False, indent=2) + '\n')
    run('xcrun', 'simctl', 'shutdown', udid)

if __name__ == '__main__':
    main()
