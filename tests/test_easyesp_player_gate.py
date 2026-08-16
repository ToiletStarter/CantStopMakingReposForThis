from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "easyesp" / "EasyESP.luau"
DOCS = ROOT / "easyesp" / "EasyESP_Documentation.md"


def test_easyesp_has_independent_player_gate():
    source = SOURCE.read_text(encoding="utf-8")
    assert "players = {" in source
    assert "function ESP:players" in source
    assert "not s.npc and not self.cfg.players.on" in source
    assert DOCS.exists()


def test_easyesp_player_gate_is_not_a_mutation_path():
    source = SOURCE.read_text(encoding="utf-8")
    assert "FireServer" not in source
    assert "InvokeServer" not in source
