"""CLI contract; Apple command line tools are the external system boundary."""
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / 'self_use.py'


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='openwithx-delivery-tests-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'Open With X.app'
        extension = self.app / 'Contents/PlugIns/FinderProbe.appex'
        for bundle, identifier in [(self.app, 'com.point.OpenWithX'),
                                   (extension, 'com.point.OpenWithX.FinderProbe')]:
            (bundle / 'Contents/MacOS').mkdir(parents=True)
            (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': identifier,
                'CFBundleExecutable': 'binary',
                'LSMinimumSystemVersion': '26.0',
            }))
            (bundle / 'Contents/MacOS/binary').touch()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        # Simulate only system tool results, never our own validation internals.
        command = '''#!/usr/bin/python3
import os, pathlib, plistlib, shutil, sys
name = os.path.basename(sys.argv[0])
scenario = os.environ.get('DELIVERY_SCENARIO', '')
if name == 'codesign':
    if '--entitlements' in sys.argv:
        sys.stdout.buffer.write(plistlib.dumps({
            'com.apple.security.app-sandbox': scenario != 'no-sandbox',
            'com.apple.security.get-task-allow': scenario == 'debug-entitlement',
            'com.apple.security.application-groups': ['RR2LFYZJUK.com.point.OpenWithX.validation'],
            'com.apple.security.files.bookmarks.app-scope': True,
            'com.apple.security.files.user-selected.read-only': True,
        }))
    elif '-dvv' in sys.argv:
        dev = scenario == 'development' or (scenario == 'development-extension' and sys.argv[-1].endswith('.appex'))
        print('Authority=' + ('Apple Development: Tester' if dev else 'Developer ID Application: Tester'), file=sys.stderr)
        print('TeamIdentifier=' + ('OTHERTEAM1' if scenario == 'wrong-team' else 'RR2LFYZJUK'), file=sys.stderr)
        print('CodeDirectory flags=' + ('0x0' if scenario == 'no-runtime' else '0x10000(runtime)'), file=sys.stderr)
        if scenario != 'no-timestamp':
            print('Timestamp=Oct 23, 2026 at 14:00:00', file=sys.stderr)
elif name == 'xcodebuild':
    if scenario == 'build-failed':
        sys.exit(70)
    if '-archivePath' in sys.argv and 'archive' in sys.argv:
        pathlib.Path(sys.argv[sys.argv.index('-archivePath') + 1]).mkdir()
    if '-exportPath' in sys.argv:
        target = pathlib.Path(sys.argv[sys.argv.index('-exportPath') + 1])
        target.mkdir()
        shutil.copytree(os.environ['DELIVERY_FIXTURE'], target / 'OpenWithX.app')
elif name == 'lipo':
    print('x86_64' if scenario == 'intel' else 'arm64')
elif name == 'xcrun' and scenario == 'not-notarized':
    sys.exit(65)
'''
        for name in ['codesign', 'lipo', 'xcrun', 'spctl', 'xcodebuild']:
            p = self.bin / name
            p.write_text(command)
            p.chmod(0o755)

    def cli(self, command, path, scenario=''):
        return subprocess.run([sys.executable, str(TOOL), command, str(path)],
                              env={**os.environ, 'PATH': str(self.bin) + ':' + os.environ['PATH'],
                                   'DELIVERY_SCENARIO': scenario, 'DELIVERY_FIXTURE': str(self.app)},
                              capture_output=True, text=True)

    def verify(self, scenario=''):
        return self.cli('verify', self.app, scenario)

    def test_rejects_development_signature(self):
        result = self.verify('development')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Developer ID Application', result.stderr)

    def test_rejects_missing_secure_timestamp(self):
        result = self.verify('no-timestamp')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Timestamp', result.stderr)

    def test_rejects_development_signed_extension(self):
        result = self.verify('development-extension')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Developer ID Application', result.stderr)

    def test_rejects_embedded_profile_in_extension(self):
        profile = self.app / 'Contents/PlugIns/FinderProbe.appex/Contents/embedded.provisionprofile'
        profile.write_bytes(b'expired profile fixture')
        result = self.verify()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Provisioning Profile', result.stderr)

    def test_rejects_missing_notarization_ticket(self):
        result = self.verify('not-notarized')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('stapler', result.stderr)

    def test_accepts_complete_private_backup(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Verified', result.stdout)

    def test_rejects_wrong_team_architecture_or_permissions(self):
        for scenario in ['wrong-team', 'no-runtime', 'no-sandbox', 'debug-entitlement', 'intel']:
            with self.subTest(scenario=scenario):
                result = self.verify(scenario)
                self.assertNotEqual(result.returncode, 0)

    def test_requires_finder_extension(self):
        import shutil
        shutil.rmtree(self.app / 'Contents/PlugIns')
        result = self.verify()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('FinderProbe', result.stderr)

    def test_build_produces_backup_and_checksum(self):
        output = self.root / 'private backup'
        result = self.cli('build', output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((output / 'OpenWithX-self-use.zip').is_file())
        self.assertIn('OpenWithX-self-use.zip', (output / 'SHA256SUMS').read_text())

    def test_build_does_not_overwrite_existing_output(self):
        result = self.cli('build', self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('exists', result.stderr)

    def test_build_failure_never_produces_ready_backup(self):
        output = self.root / 'failed'
        result = self.cli('build', output, 'build-failed')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('archive.log', result.stderr)
        self.assertFalse((output / 'OpenWithX-self-use.zip').exists())


if __name__ == '__main__':
    unittest.main()
