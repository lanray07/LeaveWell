import json
import subprocess
import time
import re
import struct
from pathlib import Path

out = Path('build/DuoProbe')
def run(*args, check=True, timeout=180):
    return subprocess.run(args, capture_output=True, text=True, check=check, timeout=timeout).stdout.strip()

devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
device = next(d for runtime, group in devices.items() if runtime.endswith('iOS-27-1') for d in group if d['name'] == 'iPhone Duo')
udid = device['udid']
app = Path('build/DerivedData/Build/Products/Debug-iphonesimulator/LeaveWell.app')
(app / 'DemoKitchen.png').write_bytes(Path('marketing/source/demo-kitchen.png').read_bytes())
run('xcrun', 'simctl', 'boot', udid, check=False)
run('xcrun', 'simctl', 'bootstatus', udid, '-b', timeout=600)
screens = run('xcrun', 'simctl', 'io', udid, 'enumerate')
(out / 'screens.txt').write_text(screens)
integrated = {}
for block in re.split(r'(?=\(\d+\) [^\n]+:)', screens):
    if 'Screen Type: Integrated' not in block:
        continue
    screen_id = re.search(r'Screen ID: (\d+)', block)
    size = re.search(r'Pixel Size: \{(\d+), (\d+)\}', block)
    if screen_id and size:
        integrated[tuple(map(int, size.groups()))] = screen_id[1]
assert (1398, 2034) in integrated and (2007, 2853) in integrated, integrated
run('xcrun', 'simctl', 'ui', udid, 'appearance', 'light')
run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100')
run('xcrun', 'simctl', 'install', udid, str(app))
container = Path(run('xcrun', 'simctl', 'get_app_container', udid, 'com.leavewell.app', 'data'))
routes = ['home', 'checkout', 'walkthrough', 'evidence', 'notes', 'meters', 'keys', 'documents', 'pair', 'report']
for family, size in [('outer', (1398, 2034)), ('inner', (2007, 2853))]:
    screen_id = integrated[size]
    for other in integrated.values():
        if other != screen_id:
            run('xcrun', 'simctl', 'io', udid, 'screenConfig', '--display=' + other, 'power', 'off')
    run('xcrun', 'simctl', 'io', udid, 'screenConfig', '--display=' + screen_id, 'power', 'on')
    folder = out / 'en-GB' / family
    folder.mkdir(parents=True, exist_ok=True)
    for index, route in enumerate(routes, 1):
        run('xcrun', 'simctl', 'terminate', udid, 'com.leavewell.app', check=False)
        marker = container / ('Documents/MarketingReady-' + route)
        marker.unlink(missing_ok=True)
        run('xcrun', 'simctl', 'launch', udid, 'com.leavewell.app', '-marketing-route', route, '-AppleLanguages', '(en-GB)', '-AppleLocale', 'en_GB')
        for attempt in range(90):
            if marker.exists():
                break
            time.sleep(1)
        else:
            raise RuntimeError('Demo route did not become ready: ' + route)
        time.sleep(3)
        path = folder / f'{index:02d}-{route}.png'
        run('xcrun', 'simctl', 'io', udid, 'screenshot', '--display=' + screen_id, str(path))
        assert struct.unpack('>II', path.read_bytes()[16:24]) == size
        print('Captured', family, route, flush=True)
