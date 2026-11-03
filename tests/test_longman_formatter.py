"""Exercise the actual Anki template script in a browser, when available."""

import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ASSETS = Path(__file__).resolve().parents[1] / "home/assets/anki"
BROWSER = next(
    (path for name in ("google-chrome-stable", "chromium", "chromium-browser")
     if (path := shutil.which(name))),
    None,
)
AUDIO = '<a class="replay-button" href="playsound:0"><svg></svg></a>'
CASES = {
    "multiple_senses": (
        "distress",
        "noun | verb<br>distress1 /dɪˈstres/ ●●○ noun [uncountable]<br>"
        "WORD ORIGIN EXAMPLES COLLOCATIONS PHRASES<br>"
        "1a feeling of extreme unhappiness:<br>"
        "\u00a0Luke’s behaviour caused his parents great distress.<br>"
        "in distress<br>\u00a0The girl was crying and clearly in distress.<br>"
        "2suffering and problems caused by a lack of money, food etc:<br>"
        "\u00a0acute financial distress<br>"
        "distress2 ●○○ verb [transitive]<br>to make someone feel very upset:" + AUDIO,
    ),
    "separate_parts_of_speech": (
        "distrust",
        "noun | verb<br>distrust1 /dɪsˈtrʌst/ ●○○ noun [uncountable]<br>"
        "EXAMPLES THESAURUS COLLOCATIONS WORD FAMILY<br>"
        "a feeling that you cannot trust someone → mistrust:<br>"
        "\u00a0Local people regard the police with suspicion and distrust.<br>"
        "distrust of<br>\u00a0Dylan’s deep distrust of journalists made him difficult to interview.<br>"
        "—distrustful adjective<br>noun | verb<br>distrust2 ●○○ verb [transitive]<br>"
        "VERB TABLE EXAMPLES WORD FAMILY<br>to not trust someone or something OPP trust:<br>"
        "\u00a0She had every reason to distrust him." + AUDIO,
    ),
    "trademark_before_main_entry": (
        "hello",
        "Hello! trademark<br>a British magazine with pictures of famous people.<br>"
        "hello (also hallo, hullo British English) /həˈləʊ, he- $ -ˈloʊ/ ●●● S1 interjection, noun [countable]<br>"
        "WORD ORIGIN EXAMPLES THESAURUS COLLOCATIONS PHRASES<br>"
        "1used as a greeting when you see or meet someone:<br>"
        "\u00a0Hello, John! How are you?<br>\u00a0Stanley, come and say hello.<br>"
        "Register<br>In everyday English people often say hi.<br>"
        "2used when answering the telephone:<br>\u00a0Hello – may I speak to Anne?" + AUDIO,
    ),
    "selected_meaning_without_header": (
        "entrust",
        "to make someone responsible for doing something important<br>"
        "entrust something/somebody to somebody<br>"
        "\ufffc She entrusted her son’s education to a private tutor.<br>"
        "be entrusted with something/somebody<br>"
        "\ufffc I was entrusted with looking after the money." + AUDIO,
    ),
    "selected_second_sense": (
        "distress",
        "2suffering and problems caused by a lack of money, food etc:<br>"
        "\u00a0acute financial distress<br>3 formal great physical pain",
    ),
    "meaning_only": ("reluctant", "not willing to do something"),
    "example_only": ("hello", "\u00a0Hello, John! How are you?"),
    "navigation_only": ("hello", "noun | verb<br>THESAURUS"),
    "manual_layout": ("distress", "<p>A manually chosen meaning.</p>" + AUDIO),
    "literal_text": ("x+y", "a value with &lt;angle brackets&gt; &amp; symbols"),
}


class AnkiAudioCompatibilityTests(unittest.TestCase):
    def test_script_cannot_be_interpreted_as_an_anki_audio_reference(self):
        template = (ASSETS / "longman-back.html").read_text()
        script = re.search(r"<script>(.*?)</script>", template, re.S).group(1)
        self.assertNotRegex(script, r"\[(?:sound|anki:play):")


@unittest.skipUnless(BROWSER, "A Chromium browser is needed for Anki template rendering")
class LongmanFormatterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        template = (ASSETS / "longman-back.html").read_text()
        script = re.search(r"<script>(.*?)</script>", template, re.S).group(1)
        markup = re.sub(r"<script>.*?</script>", "", template, flags=re.S)
        markup = re.sub(r"{{#marked_sentence}}.*?{{/marked_sentence}}", "", markup, flags=re.S)
        cases = [
            {
                "name": name,
                "html": markup.replace("{{text:Word}}", html.escape(word, quote=True))
                              .replace("{{Word}}", html.escape(word))
                              .replace("{{selected_text}}", selection),
            }
            for name, (word, selection) in CASES.items()
        ]
        harness = """
        var results = {};
        cases.forEach(function (item) {
          document.getElementById("fixture").innerHTML = item.html;
          (0, eval)(formatter);
          var source = document.querySelector(".lm-definition");
          function text(selector) {
            var element = source.querySelector(selector);
            return element ? element.textContent : null;
          }
          var original = source.querySelector(".lm-original");
          results[item.name] = {
            meaning: text(".lm-meaning"),
            example: text(".lm-example"),
            phrase: text(".lm-phrase"),
            metadata: text(".lm-meta"),
            original: text(".lm-original-text"),
            collapsed: original ? !original.open : null,
            audio: source.querySelectorAll(".replay-button").length,
            originalAudio: original ? original.querySelectorAll(".replay-button").length : 0,
            fullText: source.textContent,
            nestedScripts: source.querySelectorAll("script").length
          };
        });
        var report = document.createElement("pre");
        report.id = "longman-test-results";
        report.textContent = JSON.stringify(results);
        document.body.appendChild(report);
        """
        document = (
            '<!doctype html><meta charset="utf-8"><div id="fixture"></div><script>'
            + "var cases = " + json.dumps(cases).replace("</", "<\\/") + ";"
            + "var formatter = " + json.dumps(script).replace("</", "<\\/") + ";"
            + harness + "</script>"
        )
        with tempfile.TemporaryDirectory() as directory:
            page = Path(directory) / "formatter.html"
            page.write_text(document)
            result = subprocess.run(
                [BROWSER, "--headless", "--no-sandbox", "--disable-gpu",
                 "--disable-dev-shm-usage", "--disable-background-networking",
                 "--no-first-run", "--user-data-dir=" + directory + "/profile",
                 "--dump-dom", page.as_uri()],
                text=True, capture_output=True, timeout=30, check=True,
            )
        report = re.search(r'<pre id="longman-test-results">(.*?)</pre>', result.stdout, re.S)
        if report is None:
            raise AssertionError("Template script did not finish: " + result.stderr[-1500:])
        cls.results = json.loads(html.unescape(report.group(1)))

    def test_one_sense_is_visible_and_all_original_senses_are_retained(self):
        result = self.results["multiple_senses"]
        self.assertEqual(result["meaning"], "a feeling of extreme unhappiness")
        self.assertEqual(result["example"], "Luke’s behaviour caused his parents great distress.")
        self.assertEqual(result["phrase"], "in distress")
        self.assertEqual(result["metadata"], "/dɪˈstres/ · noun [uncountable]")
        self.assertTrue(result["collapsed"])
        self.assertIn("great physical pain", self.results["selected_second_sense"]["original"])
        self.assertIn("to make someone feel very upset", result["original"])

    def test_audio_is_visible_once_and_not_duplicated_in_collapsed_text(self):
        for name in ("multiple_senses", "separate_parts_of_speech", "trademark_before_main_entry"):
            with self.subTest(name=name):
                self.assertEqual(self.results[name]["audio"], 1)
                self.assertEqual(self.results[name]["originalAudio"], 0)

    def test_different_parts_of_speech_do_not_mix(self):
        result = self.results["separate_parts_of_speech"]
        self.assertEqual(result["meaning"], "a feeling that you cannot trust someone → mistrust")
        self.assertEqual(result["example"], "Local people regard the police with suspicion and distrust.")
        self.assertEqual(result["phrase"], "distrust of")
        self.assertNotIn("verb", result["metadata"])

    def test_ordinary_entry_is_chosen_over_trademark(self):
        result = self.results["trademark_before_main_entry"]
        self.assertEqual(result["meaning"], "used as a greeting when you see or meet someone")
        self.assertEqual(result["example"], "Hello, John! How are you?")
        self.assertIn("interjection, noun", result["metadata"])
        self.assertNotIn("magazine", result["meaning"])
        self.assertIsNone(result["phrase"])

    def test_partial_selection_does_not_invent_metadata_or_examples(self):
        result = self.results["selected_meaning_without_header"]
        self.assertEqual(result["meaning"], "to make someone responsible for doing something important")
        self.assertIsNone(result["metadata"])
        self.assertEqual(result["example"], "She entrusted her son’s education to a private tutor.")
        self.assertNotIn("\ufffc", result["fullText"])
        self.assertEqual(self.results["selected_second_sense"]["meaning"],
                         "suffering and problems caused by a lack of money, food etc")
        self.assertIsNone(self.results["meaning_only"]["example"])

    def test_unrecognized_or_manual_content_keeps_its_original_display(self):
        for name in ("example_only", "navigation_only", "manual_layout"):
            with self.subTest(name=name):
                self.assertIsNone(self.results[name]["meaning"])
                self.assertIsNone(self.results[name]["collapsed"])
        self.assertIn("A manually chosen meaning.", self.results["manual_layout"]["fullText"])
        self.assertEqual(self.results["manual_layout"]["audio"], 1)

    def test_dictionary_text_is_rendered_literally(self):
        result = self.results["literal_text"]
        self.assertEqual(result["meaning"], "a value with <angle brackets> & symbols")
        self.assertEqual(result["nestedScripts"], 0)


if __name__ == "__main__":
    unittest.main()
