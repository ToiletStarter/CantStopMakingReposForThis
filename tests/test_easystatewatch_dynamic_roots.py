from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "easystate" / "EasyStateWatch.luau"
DOCS = ROOT / "easystate" / "EasyStateWatch_Documentation.md"


def test_statewatch_supports_dynamic_roots():
    source = SOURCE.read_text(encoding="utf-8")
    for name in ["setRootProvider", "resolvedRoots"]:
        assert f"function StateWatch:{name}" in source
    assert "self.rootProvider" in source
    assert "ipairs(self:resolvedRoots())" in source


def test_statewatch_dynamic_root_docs_exist():
    docs = DOCS.read_text(encoding="utf-8")
    assert "rootProvider" in docs
    assert "setRootProvider" in docs
