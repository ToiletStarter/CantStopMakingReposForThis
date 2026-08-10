from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class ObservabilityModuleTests(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_all_observability_modules_and_docs_exist(self):
        for folder, module, docs in [
            ("easysignals", "EasySignals.luau", "EasySignals_Documentation.md"),
            ("easyreport", "EasyReport.luau", "EasyReport_Documentation.md"),
            ("easystats", "EasyStats.luau", "EasyStats_Documentation.md"),
            ("easystate", "EasyStateWatch.luau", "EasyStateWatch_Documentation.md"),
            ("easytrace", "EasyRemoteTrace.luau", "EasyRemoteTrace_Documentation.md"),
        ]:
            self.assertTrue((ROOT / folder / module).exists())
            self.assertTrue((ROOT / folder / docs).exists())

    def test_remote_trace_is_metadata_first_and_forwarding(self):
        source = self.read("easytrace/EasyRemoteTrace.luau")
        self.assertIn('self.mode = options.mode or "metadata"', source)
        self.assertIn("self.allowRaw = options.allowRaw == true", source)
        self.assertIn("argTypes = argTypes(argc, ...)", source)
        self.assertIn("local args = table.pack(...)", source)
        self.assertIn("return trace.oldNamecall(remote, table.unpack(args, 1, args.n))", source)
        self.assertIn('hookmetamethod(game, "__namecall", closure)', source)

    def test_state_watch_has_hard_bounds_and_initial_diff(self):
        source = self.read("easystate/EasyStateWatch.luau")
        self.assertIn("self.maxDepth = options.maxDepth or 5", source)
        self.assertIn("self.maxNodes = options.maxNodes or 3000", source)
        self.assertIn("self.maxChanges = options.maxChanges or 200", source)
        self.assertIn("out.initial = true", source)
        self.assertIn("counters.truncated = true", source)

    def test_report_redacts_and_bounds_output(self):
        source = self.read("easyreport/EasyReport.luau")
        for word in ["token", "password", "secret", "authorization", "cookie"]:
            self.assertIn(word, source)
        self.assertIn("self.maxEntries = options.maxEntries or 500", source)
        self.assertIn("self.maxBytes = options.maxBytes or 120000", source)
        self.assertIn('return "[REDACTED]"', source)
        self.assertIn("report:flushDue", self.read("easyreport/EasyReport_Documentation.md"))

    def test_stats_and_signals_register_with_easystack(self):
        self.assertIn('Stack.register("signals.library", EasySignals)', self.read("easysignals/EasySignals.luau"))
        self.assertIn('Stack.register("stats.library", Stats)', self.read("easystats/EasyStats.luau"))
        self.assertIn('Stack.register("state.library", StateWatch)', self.read("easystate/EasyStateWatch.luau"))
        self.assertIn('Stack.register("trace.library", Trace)', self.read("easytrace/EasyRemoteTrace.luau"))
        self.assertIn('Stack.register("report.library", Report)', self.read("easyreport/EasyReport.luau"))

    def test_readme_lists_observability_modules(self):
        readme = self.read("README.md")
        for name in ["EasySignals", "EasyReport", "EasyStats", "EasyStateWatch", "EasyRemoteTrace"]:
            self.assertIn(name, readme)


if __name__ == "__main__":
    unittest.main()
