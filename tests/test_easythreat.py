from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "easythreat" / "EasyThreat.luau"
DOCS = Path(__file__).resolve().parents[1] / "easythreat" / "EasyThreat_Documentation.md"


def test_threat_exposes_observation_lifecycle():
    source = SOURCE.read_text(encoding="utf-8")
    for name in ["new", "sample", "records", "get", "paths", "snapshot", "start", "stop", "destroy"]:
        assert f"function Threat:{name}" in source or f"function Threat.{name}" in source


def test_threat_has_explicit_inferred_classification():
    source = SOURCE.read_text(encoding="utf-8")
    for value in ["TARGETED", "ATTACKING", "APPROACHING", "NEAR", "CLOSING", "IDLE", "inferred"]:
        assert value in source
    assert "futurePath" in source
    assert "prediction" in source
    assert "futureSteps" in source


def test_threat_is_read_only():
    source = SOURCE.read_text(encoding="utf-8")
    forbidden = ["FireServer", "InvokeServer", "keypress", "mouse1", "HumanoidRootPart.CFrame", "WalkSpeed ="]
    assert not any(token in source for token in forbidden)
    assert DOCS.exists()
