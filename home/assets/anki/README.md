# Anki card templates and styles

## Longman vocabulary cards

GoldenDict-ng sends vocabulary to the `Longman` note type using `Word`,
`selected_text`, and `marked_sentence`. The Longman templates provide a reading
column, light and dark colors, audio replay styling, and a link back to GoldenDict.
The answer shows lookup context only when it contains more than the headword.
The back template automatically presents one English meaning, one example, and
one phrase from the selected Longman text, with IPA and part of speech when
available. It omits navigation labels and additional senses from the short view;
**Full selection** expands the complete imported text. Audio remains visible once.
This runs inside the template, so new imports automatically use the same layout
without an additional service, port, API, or manual editing. The template and its
script travel with Anki Sync.

The display script also hides object-replacement glyphs left by dictionary icons.
It does not translate, invent missing examples, or change stored note fields.
Hand-formatted paragraph/list/table content retains its layout; unrecognized
selections remain visible in full.

Home Manager installs `anki-longman-setup` and configures GoldenDict's connection,
field mapping, audio setting, and `~/Dictionary/Longman` dictionary path. It defers
GoldenDict edits if the app is running. AnkiConnect still needs to be installed
once in Anki; dictionary files and AnkiWeb login are personal data, kept outside
the repository.

On another machine, sync the existing AnkiWeb collection first; the note type,
templates, review history, and media travel with the collection. Quit GoldenDict
using its tray menu, open Anki with AnkiConnect enabled, close the card template
editor, and run:

```bash
anki-longman-setup
```

The command finishes GoldenDict setup and verifies/applies the repository's
Longman templates. It refuses to create a missing note type/deck by default so
you can sync your existing collection first. For a genuinely new collection with
no existing vocabulary to restore, use `anki-longman-setup --initialize`; this
creates the note type and empty `LongMan` deck, but no notes.

The complete migration steps, including the AnkiConnect installation code and a
connection check, are in the [installation runbook](../../../docs/personal/installation.md#restore-goldendict--anki).

To update only Anki's templates from a checkout, without changing GoldenDict:

```bash
python3 home/assets/anki/apply-longman.py
```

The Python command updates the existing single card template and CSS of `Longman`.
It verifies the result without creating notes, changing fields, or touching
review scheduling. It writes no backup files. Other note types retain their
existing templates and styles.

To edit the design, update [`longman-front.html`](longman-front.html),
[`longman-back.html`](longman-back.html), or [`longman.css`](longman.css), then run
the command again. You can also paste these files into Anki's Front Template,
Back Template, and Styling tabs under **Tools → Manage Note Types → Longman → Cards**.

For new vocabulary, select a relevant definition and example in GoldenDict-ng and
use **Send to Anki** as usual. If you select the whole entry, the short view uses
the first ordinary entry and its first meaning/example; it cannot infer which
sense you encountered in your reading. To learn a later sense, select that part.
IPA and part of speech can only be shown when present in the selection. The
built-in `Sentence` mapping still sends the lookup string; the example in the
short view is extracted from `selected_text`, not from that lookup field.

## Yanki stylesheet

[`yanki-dark.css`](yanki-dark.css) styles Yanki-managed Anki note types. It provides a Markdown-friendly layout, scales standalone formulas, and applies dark colors to Shiki code blocks in Anki Night Mode. Its colors are maintained independently of the desktop palette.

### Apply the stylesheet

1. Open Anki with AnkiConnect enabled.
2. Close any open Anki card editor.
3. Run the following command from the repository root:

```bash
nix shell nixpkgs#nodejs_22 -c npx --yes yanki style --css "$PWD/home/assets/anki/yanki-dark.css"
```

The command updates the styling of Yanki-managed note types in the open collection. Other note types retain their existing styles.

See the [configuration notes](../../../docs/README.md) for general usage and maintenance.
