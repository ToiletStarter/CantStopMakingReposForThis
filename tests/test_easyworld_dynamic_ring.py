from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "easyworld" / "EasyWorld.luau"


def test_world_ring_accepts_dynamic_radius():
    source = SOURCE.read_text(encoding="utf-8")
    assert "function dynamicValue" in source
    assert "local baseRad = dynamicValue(spec.rad, 10)" in source
    assert "function World:ring" in source
