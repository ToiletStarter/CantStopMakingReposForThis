from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "easyui" / "EasyUi_style_2.luau"
DOCS = ROOT / "easyui" / "EasyUi_style_2_Documentation.md"
README = ROOT / "README.md"


def test_style2_exposes_release_surface():
    source = SOURCE.read_text(encoding="utf-8")
    docs = DOCS.read_text(encoding="utf-8")
    readme = README.read_text(encoding="utf-8")
    for token in (
        "function tab:SubTab",
        "function UI:SetGrouped",
        "function UI:ShowAll",
        "function UI:Popup",
        "function UI:SetStyle",
        "function UI:SetToggleKey",
        "function UI:SetCursorVisible",
        "local resizeHandle",
        "local DROPDOWN",
        "priority = opts.priority == true",
        "function Section:Grid",
        "function Section:Columns",
        "compact = opts.compact == true",
        "separator = opts.separator or \" | \"",
        "self._syncingFlags",
        "function UI:_bindContext",
        "MouseButton2",
        "_contextPopup",
        "opts.cursor ~= false",
    ):
        assert token in source
    for token in ("SubTab", "resize", "SetStyle", "priority = true", "custom cursor"):
        assert token.lower() in docs.lower()
    assert "subtabs" in readme.lower()
    assert "resizable" in readme.lower()


def test_style2_has_no_game_mutation_surface():
    source = SOURCE.read_text(encoding="utf-8")
    for token in (
        "FireServer",
        "InvokeServer",
        "hookmetamethod",
        "hookfunction",
        "keypress",
        "mouse1click",
        "WalkSpeed =",
        "JumpPower =",
    ):
        assert token not in source
