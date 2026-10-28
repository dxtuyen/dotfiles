# Yanki card stylesheet

`yanki-dark.css.in` is the template used by Yanki-managed Anki note types. Home Manager substitutes the shared Gruvbox Material palette and installs the result at `~/.config/anki/yanki-dark.css`. It keeps a Markdown-friendly layout, scales standalone formulas, and applies dark colors to Shiki code blocks in Anki Night Mode.

After rebuilding, apply the generated stylesheet with Anki open and AnkiConnect enabled. Close any Anki card editor first:

```sh
nix shell nixpkgs#nodejs_22 -c npx --yes yanki style --css "$HOME/.config/anki/yanki-dark.css"
```

The stylesheet affects Yanki-managed note types, not Anki's other default note types.
