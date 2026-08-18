# VS2026 Dark (VS Parity)

A VS Code color theme matching Visual Studio 2026 syntax colors for TypeScript and C#,
pixel-verified against real VS 2026 screenshots. Built 2026-08-16.

- Base token rules: [ZTex275.dark-theme-vs2026](https://marketplace.visualstudio.com/items?itemName=ZTex275.dark-theme-vs2026)
- Workbench colors: [SoVoKaN.dark-theme-vs2022](https://marketplace.visualstudio.com/items?itemName=SoVoKaN.dark-theme-vs2022) (editor `#1E1E1E`, replacing the VS2026 fork's Cursor-styled UI)
- Plus hand-tuned semantic/TextMate fixes for C# XML doc comments, records, extension
  methods, and the TS-vs-C# palette split (strings, control-flow purple, property blue).
  See the comments in `build-theme.mjs` for the full list.

## Install

From this directory, copy it into the local extensions folder, restart VS Code,
and pick the theme with `Ctrl+K Ctrl+T` ("VS2026 Dark (VS Parity)"):

```pwsh
Copy-Item -Recurse -Force . "$env:USERPROFILE\.vscode\extensions\mkrauz.vs2026-dark-parity-1.0.0"
```

```sh
cp -r . ~/.vscode/extensions/mkrauz.vs2026-dark-parity-1.0.0
```

Optional: `"editor.fontLigatures": true` with Cascadia Code gets the VS-style
`!=` / `=>` glyphs.

## Rebuilding from upstream

The committed `themes/vs2026-parity-color-theme.json` is the source of truth;
`build-theme.mjs` regenerates it from the two upstream themes. To re-derive
(e.g. after an upstream update), download each extension's `.vsix` from the
marketplace, extract (a `.vsix` is a zip) into `vendor/<publisher>.<name>/`
so the theme JSON sits at `vendor/<id>/extension/themes/dark-color-theme.json`,
then run `node build-theme.mjs`. The `vendor/` directory is not committed.
