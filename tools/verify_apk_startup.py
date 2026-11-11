"""Install the exported APK and verify its actual Android surface is not black."""

import argparse
from hashlib import sha256
from io import BytesIO
import json
import os
from pathlib import Path
import subprocess
import time

from PIL import Image


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk', type=Path)
parser.add_argument('--device', default='emulator-5554')
parser.add_argument('--skip-install', action='store_true')
parser.add_argument('--output', type=Path, default=Path('build/diagnostics/release-startup'))
args = parser.parse_args()
adb = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or
           Path(os.environ['LOCALAPPDATA']) / 'Android' / 'sdk') / 'platform-tools' / 'adb.exe'
package = 'vn.edu.hutech.pawpals_app'
args.output.mkdir(parents=True, exist_ok=True)


def command(*parts, timeout=30):
    return subprocess.check_output([str(adb), '-s', args.device, *parts], timeout=timeout)


booted = command('shell', 'getprop', 'sys.boot_completed').decode().strip()
boot_animation = command('shell', 'getprop', 'init.svc.bootanim').decode().strip()
if booted != '1' or boot_animation == 'running':
    raise SystemExit('Wait for Android to finish booting before checking the APK.')

if not args.skip_install:
    result = command('install', '-r', str(args.apk.resolve()), timeout=120).decode()
    if 'Success' not in result:
        raise RuntimeError('APK installation failed: ' + result)

command('shell', 'am', 'force-stop', package)
command('shell', 'am', 'start', '-W', '-n', package + '/.MainActivity')
started = time.monotonic()
samples = []
stable_frames = 0
time.sleep(8)
while time.monotonic() - started < 45:
    png = command('exec-out', 'screencap', '-p')
    (args.output / 'screen.png').write_bytes(png)
    with Image.open(BytesIO(png)) as image:
        rgb = image.convert('RGB')
        # Exclude system bars so their icons cannot make a black app pass.
        pixels = [rgb.getpixel((x, y))
                  for y in range(rgb.height // 10, rgb.height * 9 // 10, 16)
                  for x in range(rgb.width // 10, rgb.width * 9 // 10, 16)]
    visible = sum(max(pixel) > 32 for pixel in pixels) / len(pixels)
    samples.append({'seconds': round(time.monotonic() - started, 1),
                    'visiblePixelFraction': round(visible, 4)})
    stable_frames = stable_frames + 1 if visible >= 0.10 else 0
    if stable_frames >= 2:
        break
    time.sleep(3)

pid = command('shell', 'pidof', package).decode().strip()
logs = command('logcat', '-d', '--pid=' + pid, '-v', 'brief').decode(errors='replace')
(args.output / 'logcat.txt').write_text(logs, encoding='utf-8')
report = {
    'apk': str(args.apk), 'sha256': sha256(args.apk.read_bytes()).hexdigest(),
    'device': args.device, 'package': package, 'samples': samples,
    'passed': stable_frames >= 2,
}
if not report['passed']:
    # A frozen emulator compositor makes every app black. Check a native
    # system activity before attributing a screenshot failure to this APK.
    command('shell', 'am', 'start', '-W', '-a', 'android.settings.SETTINGS')
    time.sleep(3)
    control = command('exec-out', 'screencap', '-p')
    (args.output / 'android-settings-control.png').write_bytes(control)
    with Image.open(BytesIO(control)) as image:
        rgb = image.convert('RGB')
        pixels = [rgb.getpixel((x, y))
                  for y in range(rgb.height // 10, rgb.height * 9 // 10, 16)
                  for x in range(rgb.width // 10, rgb.width * 9 // 10, 16)]
    control_visible = sum(max(pixel) > 32 for pixel in pixels) / len(pixels)
    report['androidSettingsVisiblePixelFraction'] = round(control_visible, 4)
    report['infrastructureHealthy'] = control_visible >= 0.10
    command('shell', 'am', 'start', '-W', '-n', package + '/.MainActivity')
(args.output / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
if not report['passed']:
    if not report.get('infrastructureHealthy', True):
        raise SystemExit('Android Settings is also black: restart the emulator before judging the APK.')
    raise SystemExit('APK opened but the Android app surface remained black.')
