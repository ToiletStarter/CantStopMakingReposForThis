from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "easyui" / "EasyUiTesting.luau"


def test_ui_has_synchronous_instance_destroy_path():
    source = SOURCE.read_text(encoding="utf-8")
    assert "function UI:_destroyNow()" in source
    assert "self._destroyed = true" in source
    assert "previous._destroyNow" in source


def test_ui_removes_orphaned_roots_before_mounting():
    source = SOURCE.read_text(encoding="utf-8")
    assert "cleanupGuiRoots" in source
    assert "EasyUI_" in source
    assert "cleanupGuiRoots()" in source


def test_ui_close_handles_unparented_instances():
    source = SOURCE.read_text(encoding="utf-8")
    assert "if not self.gui or not self.gui.Parent then" in source
    assert "self:_destroyNow()" in source
