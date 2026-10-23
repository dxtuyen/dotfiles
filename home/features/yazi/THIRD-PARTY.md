# Third-party material

## Yazi icon data

The `[icon]` block in `theme.toml` is derived from Yazi's built-in
`theme-dark.toml` preset: the icon glyphs, file/extension/directory mappings
and table structure are taken verbatim, only the `fg` colours were remapped.

- Upstream: https://github.com/sxyazi/yazi — MIT License, Copyright (c) 2023 - sxyazi
- Icon data originates from nvim-tree — MIT License, Copyright (c) 2023 nvim-tree
  (see `LICENSE-ICONS` in the Yazi repository)

Both are MIT-licensed; their notices are reproduced below.

```
MIT License

Copyright (c) 2023 - sxyazi
Copyright (c) 2023 nvim-tree

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Gruvbox palette

Colour values follow the Gruvbox palette by Pavel Pertsev:
https://github.com/morhetz/gruvbox — MIT/X11 License.

## Syntax highlighting theme

`gruvbox-dark.tmTheme` is original work, written for this repository and
covered by its MIT licence. It is not derived from any existing `.tmTheme`.

Its scope-to-colour mapping follows the highlight links defined in
morhetz/gruvbox's own vim colorscheme (Comment=gray, String=green,
Constant=purple, Statement/Keyword=red, Identifier=blue, Function=green bold,
Type=yellow, StorageClass=orange, PreProc=aqua, Operator=Normal) — a mapping
rule, not copied code.

The Gruvbox `.tmTheme` commonly paired with Yazi comes from
https://github.com/poperigby/gruvbox-dark-yazi and is licensed **AGPL-3.0**.
It is deliberately **not** used or bundled here: doing so would force
AGPL-3.0 on this repository.
