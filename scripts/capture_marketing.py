"""Capture real Debug app views on GitHub's macOS runner; no invented UI."""
import json
import subprocess
import time
import os
import argparse
from pathlib import Path

def run(*args, check=True, timeout=180):
    return subprocess.run(args, check=check, capture_output=True, text=True, timeout=timeout).stdout.strip()

devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
parser = argparse.ArgumentParser()
parser.add_argument('--family', choices=['iphone', 'ipad', 'both'], default='both')
options = parser.parse_args()
available = [device for group in devices.values() for device in group]
routes = ['home', 'room', 'evidence', 'notes', 'meters', 'keys', 'documents', 'comparison', 'plan', 'report']
app = Path('build/DerivedData/Build/Products/Debug-iphonesimulator/LeaveWell.app')
(app / 'DemoKitchen.png').write_bytes(Path('marketing/source/demo-kitchen.png').read_bytes())
run('xcrun', 'simctl', 'shutdown', 'all', check=False)
for family, match in [('iphone', 'iPhone'), ('ipad', 'iPad Pro 13')]:
    if options.family not in ('both', family):
        continue
    candidates = [d for d in available if match in d['name']]
    if not candidates:
        raise RuntimeError('No available simulator for ' + family)
    device = next((d['udid'] for d in candidates if d['udid'] == os.environ.get('SIMULATOR_DEVICE')), candidates[0]['udid'])
    print('Capturing', family, candidates[0]['name'], flush=True)
    run('xcrun', 'simctl', 'boot', device, check=False)
    # First boot on hosted macOS can need several minutes for OS migration.
    run('xcrun', 'simctl', 'bootstatus', device, '-b', timeout=600)
    run('xcrun', 'simctl', 'ui', device, 'appearance', 'light')
    run('xcrun', 'simctl', 'status_bar', device, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
    run('xcrun', 'simctl', 'install', device, str(app))
    container = Path(run('xcrun', 'simctl', 'get_app_container', device, 'com.leavewell.app', 'data'))
    destination = Path('build/MarketingRaw') / family
    destination.mkdir(parents=True, exist_ok=True)
    for index, route in enumerate(routes, 1):
        run('xcrun', 'simctl', 'terminate', device, 'com.leavewell.app', check=False)
        marker = container / 'Documents' / ('MarketingReady-' + route)
        marker.unlink(missing_ok=True)
        run('xcrun', 'simctl', 'launch', device, 'com.leavewell.app', '-marketing-route', route)
        for attempt in range(60):
            if marker.exists():
                break
            time.sleep(1)
        else:
            raise RuntimeError('App did not prepare marketing route ' + route)
        time.sleep(4)
        run('xcrun', 'simctl', 'io', device, 'screenshot', str(destination / f'{index:02d}-{route}.png'))
        print('Captured', family, route, flush=True)
    run('xcrun', 'simctl', 'shutdown', device)
