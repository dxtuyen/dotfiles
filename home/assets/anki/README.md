# Yanki card stylesheet

[`yanki-dark.css`](yanki-dark.css) styles Yanki-managed Anki note types. It provides a Markdown-friendly layout, scales standalone formulas, and applies dark colors to Shiki code blocks in Anki Night Mode. Its colors are maintained independently of the desktop palette.

## Apply the stylesheet

1. Open Anki with AnkiConnect enabled.
2. Close any open Anki card editor.
3. Run the following command from the repository root:

```bash
nix shell nixpkgs#nodejs_22 -c npx --yes yanki style --css "$PWD/home/assets/anki/yanki-dark.css"
```

The command updates the styling of Yanki-managed note types in the open collection. Other note types retain their existing styles.

See the [configuration notes](../../../docs/README.md) for general usage and maintenance.
