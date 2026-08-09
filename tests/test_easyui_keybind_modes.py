from pathlib import Path
import unittest


SOURCE = Path(__file__).parents[1] / "easyui" / "EasyUiTesting.luau"


class EasyUIKeybindModeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_registration_applies_default_mode_before_context_opens(self):
        self.assertIn("wd.bindMode = normalizeBindMode(savedMode or wd.opt and wd.opt.bindMode)", self.source)

    def test_config_exports_both_modes(self):
        self.assertIn('binds["mode." .. tostring(bindId)] = normalizeBindMode(widget.bindMode)', self.source)

    def test_config_import_updates_runtime_mode_and_mode_flag(self):
        self.assertIn("widget.bindMode = normalizeBindMode(packedMode)", self.source)
        self.assertIn("self:_write(bindModeFlag(bindId), widget.bindMode)", self.source)

    def test_hold_release_never_replays_one_shot_activation(self):
        marker = "\tself:_connect(Input.InputEnded, function(i)\n\t\tif i.KeyCode == Enum.KeyCode.Unknown"
        release = self.source.split(marker, 1)[1].split("\tself:_ctxInit()", 1)[0]
        self.assertNotIn("task.spawn(wd.activate)", release)
        self.assertIn("elseif wd.release then", release)

    def test_mode_helpers_are_shared(self):
        self.assertIn("local function normalizeBindMode", self.source)
        self.assertIn("local function bindModeFlag", self.source)
        self.assertIn("local function widgetBindId", self.source)


if __name__ == "__main__":
    unittest.main()
