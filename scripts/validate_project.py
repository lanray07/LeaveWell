"""Check project references, plists, assets and the localization catalog without Xcode."""
from pathlib import Path
import json
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / 'LeaveWell.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
for file in (ROOT / 'LeaveWell').rglob('*.swift'):
    assert file.relative_to(ROOT).as_posix() in project, f'Unreferenced source: {file}'
for path in re.findall(r'path = "([^"]+)"; sourceTree = SOURCE_ROOT;', project):
    assert (ROOT / path).exists(), f'Missing project file: {path}'
for file in (ROOT / 'LeaveWell/Resources').glob('*.plist'):
    with file.open('rb') as stream: plistlib.load(stream)
with (ROOT / 'LeaveWell/Resources/PrivacyInfo.xcprivacy').open('rb') as stream:
    privacy = plistlib.load(stream); assert privacy['NSPrivacyTracking'] is False
for file in (ROOT / 'LeaveWell/Resources/Assets.xcassets').rglob('Contents.json'):
    asset = json.loads(file.read_text(encoding='utf-8'))
    for image in asset.get('images', []):
        if 'filename' in image: assert (file.parent / image['filename']).exists()
subprocess.run([sys.executable, str(ROOT / 'scripts/localization.py'), '--check'], check=True)
print('Project source references, plists, asset references and privacy manifest validated.')
