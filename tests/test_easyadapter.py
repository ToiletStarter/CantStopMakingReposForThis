from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "easyadapter" / "EasyAdapter.luau"
DOCS = ROOT / "easyadapter" / "EasyAdapter_Documentation.md"
README = ROOT / "README.md"


def test_adapter_exposes_source_and_binding_lifecycle():
    source = SOURCE.read_text(encoding="utf-8")
    for name in ["new", "addSource", "addTagSource", "addFolderSource", "attachESP", "detachESP", "setOption", "bindWorld", "unbindWorld", "snapshot", "destroy"]:
        assert f"function Adapter:{name}" in source or f"function Adapter.{name}" in source


def test_adapter_accepts_static_or_dynamic_world_positions():
    source = SOURCE.read_text(encoding="utf-8")
    assert "local getter = spec.get or spec.pos" in source
    assert "type(getter) == \"function\"" in source


def test_adapter_is_observation_only():
    source = SOURCE.read_text(encoding="utf-8")
    forbidden = ["FireServer", "InvokeServer", "hookmetamethod", "hookfunction", "keypress", "mouse1", "HumanoidRootPart.CFrame"]
    assert not any(token in source for token in forbidden)


def test_adapter_docs_and_readme_are_wired():
    assert DOCS.exists()
    readme = README.read_text(encoding="utf-8")
    assert "EasyAdapter" in readme
    assert "easyadapter/EasyAdapter.luau" in readme
