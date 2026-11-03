"""Protect existing dictionaries and collections during vocabulary setup."""

import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


def load_script(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


goldendict = load_script("configure_goldendict", "home/desktop/configure-goldendict.py")
longman = load_script("apply_longman", "home/assets/anki/apply-longman.py")


class GoldenDictConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.config = Path(self.directory.name) / "goldendict" / "config"
        self.dictionary = Path(self.directory.name) / "Dictionary" / "Longman"

    def test_fresh_install_is_private_and_repeated_setup_is_unchanged(self):
        self.assertTrue(goldendict.configure(self.config, self.dictionary))
        original = self.config.read_bytes()
        root = ET.fromstring(original)
        anki = root.find("./preferences/ankiConnectServer")
        self.assertEqual(anki.get("enabled"), "1")
        self.assertEqual(anki.findtext("word"), "Word")
        self.assertEqual(root.findtext("./paths/path"), str(self.dictionary))
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertFalse(goldendict.configure(self.config, self.dictionary))
        self.assertEqual(self.config.read_bytes(), original)

    def test_existing_dictionaries_groups_and_unmanaged_preferences_survive(self):
        self.config.parent.mkdir()
        self.config.write_text(
            '<config><!--keep--><paths><path recursive="1">/other/dictionary</path></paths>'
            '<groups><group id="7" name="English"><dictionary id="abc"/></group></groups>'
            '<preferences><scanPopupUseUIAutomation>1</scanPopupUseUIAutomation>'
            '<ankiConnectServer enabled="0"><word>word</word><futureOption>keep</futureOption>'
            '</ankiConnectServer></preferences></config>',
            encoding="utf-8",
        )
        self.config.chmod(0o640)
        goldendict.configure(self.config, self.dictionary)
        root = ET.parse(self.config).getroot()
        self.assertEqual(
            [(node.text, node.get("recursive")) for node in root.findall("./paths/path")],
            [("/other/dictionary", "1"), (str(self.dictionary), "0")],
        )
        self.assertEqual(root.find("./groups/group/dictionary").get("id"), "abc")
        self.assertEqual(root.findtext("./preferences/scanPopupUseUIAutomation"), "1")
        self.assertEqual(root.findtext("./preferences/ankiConnectServer/futureOption"), "keep")
        self.assertIn("<!--keep-->", self.config.read_text())
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o640)

    def test_malformed_config_is_not_replaced(self):
        self.config.parent.mkdir()
        self.config.write_text("<config><preferences>")
        with self.assertRaises(ET.ParseError):
            goldendict.configure(self.config, self.dictionary)
        self.assertEqual(self.config.read_text(), "<config><preferences>")

    def test_running_app_defers_activation_and_refuses_manual_edits(self):
        args = ["configure-goldendict", "--config", str(self.config), "--dictionary", str(self.dictionary)]
        with patch.object(goldendict, "goldendict_running", return_value=True):
            with patch("sys.argv", args):
                with self.assertRaisesRegex(RuntimeError, "Quit GoldenDict"):
                    goldendict.main()
            with patch("sys.argv", args + ["--skip-running"]), patch("builtins.print"):
                goldendict.main()
        self.assertFalse(self.config.exists())


class LongmanInitializationTests(unittest.TestCase):
    def test_missing_synced_data_does_not_create_an_empty_replacement(self):
        def api(action, **params):
            if action in ("modelNames", "deckNames"):
                return []
            self.fail(f"Unexpected mutation before sync: {action}")

        with patch.object(longman, "anki", side_effect=api), patch("sys.argv", ["apply-longman"]):
            with self.assertRaisesRegex(RuntimeError, "Sync your existing AnkiWeb"):
                longman.main()

    def test_explicit_fresh_install_creates_one_model_and_deck_without_notes(self):
        models, decks, mutations = {}, [], []

        def api(action, **params):
            if action == "modelNames":
                return list(models)
            if action == "deckNames":
                return list(decks)
            if action == "createModel":
                models[params["modelName"]] = params
                mutations.append(action)
                return {}
            if action == "createDeck":
                decks.append(params["deck"])
                mutations.append(action)
                return 1
            model = models["Longman"]
            if action == "modelFieldNames":
                return model["inOrderFields"]
            if action == "modelTemplates":
                return {t["Name"]: {k: t[k] for k in ("Front", "Back")} for t in model["cardTemplates"]}
            if action == "modelStyling":
                return {"css": model["css"]}
            self.fail(f"Unexpected collection operation: {action}")

        with patch.object(longman, "anki", side_effect=api), patch("builtins.print"):
            with patch("sys.argv", ["apply-longman", "--initialize"]):
                longman.main()
            with patch("sys.argv", ["apply-longman"]):
                longman.main()
        self.assertEqual(mutations, ["createModel", "createDeck"])
        self.assertEqual(decks, ["LongMan"])


if __name__ == "__main__":
    unittest.main()
