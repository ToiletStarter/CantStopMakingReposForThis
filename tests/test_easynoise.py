from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "easynoise" / "EasyNoise.luau"
DOCS = Path(__file__).resolve().parents[1] / "easynoise" / "EasyNoise_Documentation.md"


def test_noise_exposes_meter_and_snapshot_lifecycle():
    source = SOURCE.read_text(encoding="utf-8")
    for name in ["new", "setMultiplier", "setThreat", "start", "stop", "estimate", "pulse", "snapshot", "destroy"]:
        assert f"function Noise:{name}" in source or f"function Noise.{name}" in source


def test_noise_does_not_send_ping_or_input():
    source = SOURCE.read_text(encoding="utf-8")
    forbidden = ["FireServer", "InvokeServer", "VoicePing", "keypress", "mouse1", "hookmetamethod"]
    assert not any(token in source for token in forbidden)
    assert "estimatedReach" in source
    assert "inferredResponses" in source
    assert DOCS.exists()
