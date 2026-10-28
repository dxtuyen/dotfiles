# Yanki card stylesheet

`yanki-dark.css` is the custom stylesheet used by Yanki-managed Anki note types. It keeps a Markdown-friendly layout, scales standalone formulas, and applies dark colors to Shiki code blocks in Anki Night Mode.

To apply it again, run this command from the root of this Nix config repository. Keep Anki open with AnkiConnect enabled, and close any Anki card editor first:

```sh
nix shell nixpkgs#nodejs_22 -c npx --yes yanki style --css "$PWD/home/assets/anki/yanki-dark.css"
```

The stylesheet affects Yanki-managed note types, not Anki's other default note types.
