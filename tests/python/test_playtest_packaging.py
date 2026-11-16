import configparser
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f'tools/{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


build = load('build_playtest')
smoke = load('smoke_playtest')
templates = load('install_export_templates')


def presets():
    parser = configparser.RawConfigParser()
    parser.optionxform = str
    parser.read(ROOT / 'export_presets.cfg')
    found = {}
    for section in parser.sections():
        if section.startswith('preset.') and not section.endswith('.options'):
            name = parser[section]['name'].strip('"')
            found[name] = (parser[section], parser[section + '.options'])
    return found


class PlaytestPackagingTest(unittest.TestCase):
    def test_windows_preset_mirrors_linux_release_settings(self):
        found = presets()
        linux, linux_options = found['Linux Playtest']
        windows, windows_options = found['Windows Playtest']
        for key in ['custom_features', 'export_filter', 'include_filter', 'exclude_filter', 'script_export_mode', 'encrypt_pck']:
            self.assertEqual(windows[key], linux[key], key)
        for key in ['binary_format/embed_pck', 'binary_format/architecture', 'texture_format/s3tc_bptc', 'texture_format/etc2_astc', 'debug/export_console_wrapper']:
            self.assertEqual(windows_options[key], linux_options[key], key)
        self.assertEqual(windows['platform'], '"Windows Desktop"')
        self.assertEqual(windows_options['codesign/enable'], 'false')

    def test_builder_smoke_and_presets_agree_per_platform(self):
        found = presets()
        for key, (preset, folder, exe, label) in build.PLATFORMS.items():
            self.assertIn(preset, found)
            self.assertEqual(found[preset][0]['export_path'].strip('"'), f'{folder}/{exe}')
            self.assertEqual(smoke.EXECUTABLES[key], exe)
            self.assertEqual(smoke.PLATFORM_LABELS[key], label)

    def test_templates_cover_both_platforms_from_pinned_archive(self):
        self.assertEqual(len(templates.SHA512), 128)
        for name in ['linux_release.x86_64', 'windows_release_x86_64.exe']:
            self.assertIn(name, templates.TEMPLATES)


if __name__ == '__main__':
    unittest.main()
