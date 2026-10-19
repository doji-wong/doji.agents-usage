import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def assert_balanced_qml(testcase, path):
    text = path.read_text(encoding="utf-8")
    stack = []
    state = "code"
    quote = ""
    index = 0
    pairs = {"}": "{", ")": "(", "]": "["}
    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if state == "code":
            if char == "/" and next_char == "/":
                state = "line"
                index += 2
                continue
            if char == "/" and next_char == "*":
                state = "block"
                index += 2
                continue
            if char in "'\"`":
                state = "string"
                quote = char
            elif char in "({[":
                stack.append(char)
            elif char in ")}]":
                testcase.assertTrue(stack, f"unmatched {char} in {path.name}")
                testcase.assertEqual(stack.pop(), pairs[char], f"mismatched {char} in {path.name}")
        elif state == "line":
            if char == "\n":
                state = "code"
        elif state == "block":
            if char == "*" and next_char == "/":
                state = "code"
                index += 2
                continue
        elif state == "string":
            if char == "\\":
                index += 2
                continue
            if char == quote:
                state = "code"
        index += 1
    testcase.assertEqual(state, "code", f"unterminated {state} in {path.name}")
    testcase.assertFalse(stack, f"unclosed delimiters in {path.name}: {stack[-3:]}")


class WidgetContractTests(unittest.TestCase):
    def test_manifest_declares_bar_widget_entrypoint(self):
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["kinds"], ["bar-widget"])
        self.assertEqual(manifest["entryPoints"]["barWidget"], "Panel.qml")

    def test_qml_sources_are_balanced(self):
        assert_balanced_qml(self, ROOT / "Main.qml")
        assert_balanced_qml(self, ROOT / "Panel.qml")

    def test_main_preserves_optional_account_and_model_fields(self):
        source = (ROOT / "Main.qml").read_text(encoding="utf-8")
        for field in ("providerId", "accountId", "accountName", "accountEmail", "currentModel", "availableModels", "recentDaysByModel"):
            self.assertIn(field, source)
        self.assertIn("providerFamilyId", source)
        self.assertIn("providerSnapshot", source)
        for field in ("usageStatusText", "authHelpText", "updatedAt"):
            self.assertIn(field, source)

    def test_panel_scopes_model_and_account_state_per_record(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        for marker in ("selectedModelId", "limitWindows(provider, selectedModelId)", "accountOptionsFor", "Account-wide", "recentDaysByModel", "tokenTotal"):
            self.assertIn(marker, source)
        self.assertIn("recordKey", source)

    def test_overview_sort_handles_missing_windows_and_stable_ties(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        for marker in ("overviewSortMode: \"all\"", "overviewAgents", "filterAgentList", "sortAgentList", "hasSessionWindow", "hasWeeklyWindow", "sortModeDescription", "sortModeTitle", "kind: windowIsLong", "period: windowPeriod"):
            self.assertIn(marker, source)

    def test_overview_filters_are_window_status_views(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        overview = source.split("// ---------- Overview: All Agents & Windows", 1)[1].split("// ---------- Status", 1)[0]

        self.assertIn('overviewSortMode: "all" // "all", "session", "weekly"', source)
        self.assertIn("primaryWindow", source)
        self.assertIn('selectedModel = "__all__"', source)
        self.assertIn("lowest remaining first", source)
        self.assertIn("setOverviewMode", source)
        self.assertIn('text: "5h"', overview)
        self.assertIn('text: "Weekly"', overview)
        self.assertIn('text: "All"', overview)
        self.assertIn('root.overviewSortMode === "session"', overview)
        self.assertIn('root.overviewSortMode === "weekly"', overview)
        self.assertNotIn('text: "Name"', overview)
        self.assertNotIn('text: "Tokens"', overview)
        self.assertNotIn("agentModelDropdown", overview)
        self.assertNotIn("todaySummaryText", overview)
        self.assertNotIn("modelData.models", overview)
        self.assertIn('visible: !root.isOverview && (root.models.length > 0 || root.modelFilterText !== "")', source)

    def test_overview_only_shows_authenticated_agents(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn("function isAgentAuthed(p)", source)
        self.assertIn("if (!isAgentAuthed(p)) continue", source)
        self.assertIn("root.overviewAgents.length === 1 ? \"1 active agent · window status\"", source)

    def test_readme_documents_additive_record_contract(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for field in ("providerId", "accountId", "accountName", "currentModel", "availableModels", "recentDaysByModel"):
            self.assertIn(f"`{field}`", readme)


if __name__ == "__main__":
    unittest.main()
