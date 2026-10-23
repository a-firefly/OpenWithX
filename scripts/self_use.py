#!/usr/bin/env python3
"""Build and verify a private Developer ID backup using Apple's native tools."""
import argparse
import hashlib
import plistlib
from pathlib import Path
import subprocess
import sys


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise ValueError(f'{" ".join(args)} failed:\n' + result.stderr.decode(errors='replace'))
    return result.stdout, result.stderr


TEAM = 'RR2LFYZJUK'
ROOT = Path(__file__).resolve().parents[1]


def verify(app, signed_only=False):
    if any(app.rglob('*.provisionprofile')) or any(app.rglob('*.mobileprovision')):
        raise ValueError('Embedded Provisioning Profile is not permitted')
    run('codesign', '--verify', '--deep', '--strict', str(app))
    extension = app / 'Contents/PlugIns/FinderProbe.appex'
    if not extension.is_dir():
        raise ValueError('Missing FinderProbe.appex')
    bundles = [app, *app.rglob('*.appex')]
    for bundle in bundles:
        _, details = run('codesign', '-dvv', str(bundle))
        text = details.decode()
        if f'TeamIdentifier={TEAM}\n' not in text or '(runtime)' not in text:
            raise ValueError(f'{bundle.name}: requires current team and Hardened Runtime')
        if 'Timestamp=' not in text:
            raise ValueError('Requires secure Timestamp')
        if 'Authority=Developer ID Application:' not in details.decode():
            raise ValueError('Requires Developer ID Application signature')
        raw, _ = run('codesign', '-d', '--entitlements', ':-', str(bundle))
        entitlements = plistlib.loads(raw)
        required = ['com.apple.security.app-sandbox',
                    'com.apple.security.files.bookmarks.app-scope',
                    'com.apple.security.files.user-selected.read-only']
        if any(entitlements.get(key) is not True for key in required):
            raise ValueError(f'{bundle.name}: missing sandbox or read-only bookmark permissions')
        if entitlements.get('com.apple.security.get-task-allow'):
            raise ValueError(f'{bundle.name}: debug entitlement is not permitted')
        if entitlements.get('com.apple.security.application-groups') != [
                f'{TEAM}.com.point.OpenWithX.validation']:
            raise ValueError(f'{bundle.name}: unexpected App Group')
        info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
        executable = bundle / 'Contents/MacOS' / info['CFBundleExecutable']
        arch, _ = run('lipo', '-archs', str(executable))
        if arch.decode().strip() != 'arm64':
            raise ValueError(f'{bundle.name}: requires arm64 only')
        if info.get('LSMinimumSystemVersion') != '26.0':
            raise ValueError(f'{bundle.name}: requires minimum macOS 26.0')

    if signed_only:
        return
    run('xcrun', 'stapler', 'validate', str(app))
    run('spctl', '--assess', '--type', 'execute', '--verbose=2', str(app))


def logged(output, name, *args):
    log = output / f'{name}.log'
    with log.open('wb') as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise ValueError(f'{name} failed; see {log}')


def finish(output):
    archive = output / 'OpenWithX.xcarchive'
    if not archive.is_dir():
        raise ValueError(f'Missing archive: {archive}')
    app = output / 'Notarized/OpenWithX.app'
    if not app.exists():
        try:
            logged(output, 'notarized', 'xcodebuild', '-exportNotarizedApp',
                   '-archivePath', str(archive), '-exportPath', str(app.parent))
        except ValueError as error:
            raise ValueError(f'{error}\nIf Apple is still processing, rerun: '
                             f'python3 scripts/self_use.py finish "{output}"') from error
    verify(app)
    backup = output / 'OpenWithX-self-use.zip'
    if backup.exists():
        raise ValueError(f'Backup already exists: {backup}; verify it instead of overwriting')
    run('ditto', '-c', '-k', '--keepParent', str(app), str(backup))
    digest = hashlib.sha256()
    with backup.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    (output / 'SHA256SUMS').write_text(f'{digest.hexdigest()}  {backup.name}\n')
    print(f'Backup ready: {backup}')


def build(output):
    output.mkdir(parents=True, exist_ok=False)
    archive = output / 'OpenWithX.xcarchive'
    logged(output, 'archive', 'xcodebuild', 'archive', '-project',
           str(ROOT / 'OpenWithX.xcodeproj'), '-scheme', 'OpenWithX',
           '-configuration', 'Release', '-destination', 'generic/platform=macOS',
           '-archivePath', str(archive), '-derivedDataPath', str(output / 'DerivedData'),
           'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=NO', 'CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO')
    logged(output, 'export', 'xcodebuild', '-exportArchive', '-archivePath', str(archive),
           '-exportPath', str(output / 'Export'), '-exportOptionsPlist',
           str(ROOT / 'Validation/SelfUseExportOptions.plist'), '-allowProvisioningUpdates')
    verify(output / 'Export/OpenWithX.app', signed_only=True)
    logged(output, 'upload', 'xcodebuild', '-exportArchive', '-archivePath', str(archive),
           '-exportOptionsPlist', str(ROOT / 'Validation/SelfUseNotarizationOptions.plist'),
           '-allowProvisioningUpdates')
    finish(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['build', 'finish', 'verify'])
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    try:
        path = args.path.resolve()
        if args.command == 'build':
            build(path)
        elif args.command == 'finish':
            finish(path)
        else:
            verify(path)
    except (ValueError, OSError, KeyError, plistlib.InvalidFileException) as error:
        print(error, file=sys.stderr)
        return 1
    if args.command == 'verify':
        print('Verified')
    return 0


if __name__ == '__main__':
    sys.exit(main())
