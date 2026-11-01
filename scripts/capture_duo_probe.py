import json
import subprocess
import time
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
(out / 'screens.txt').write_text(run('xcrun', 'simctl', 'io', udid, 'enumerate'))
run('xcrun', 'simctl', 'ui', udid, 'appearance', 'light')
run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100')
run('xcrun', 'simctl', 'install', udid, str(app))
container = Path(run('xcrun', 'simctl', 'get_app_container', udid, 'com.leavewell.app', 'data'))
marker = container / 'Documents/MarketingReady-home'
marker.unlink(missing_ok=True)
run('xcrun', 'simctl', 'launch', udid, 'com.leavewell.app', '-marketing-route', 'home')
for attempt in range(90):
    if marker.exists():
        break
    time.sleep(1)
else:
    raise RuntimeError('Demo home did not become ready')
time.sleep(4)
run('xcrun', 'simctl', 'io', udid, 'screenshot', str(out / 'native-home.png'))
