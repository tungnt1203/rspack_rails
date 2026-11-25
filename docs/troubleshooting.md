# Troubleshooting

[Back to the README](../README.md)

Start with `bin/rails rspack:doctor`. It covers the usual setup mistakes and says what to fix.

## `export 'foo' (imported as 'foo') was not found` fails the build

Since Rspack 2, importing a name that a module does not export is an error, not a warning. It often shows up after migrating from importmap, where the browser only failed when the code ran.

Fix the import, or turn it back into a warning in `rspack.config.mjs`:

```js
module: { parser: { javascript: { exportsPresence: "warn" } }, rules: [/* ... */] },
```

## Pages load old code after I stop the dev server

`public/rspack` holds the last `bin/rails rspack:build`, which is what pages link while the dev server is stopped. Run `bin/rails rspack:build` to refresh it. It also runs before tests and `assets:precompile`.

## `rspack has no entry named "application"`

No build lists that entry yet. Start the dev server with `bin/dev`, or run `bin/rails rspack:build`. For a new file in `app/javascript/entrypoints/`, restart the dev server. The message names the entries the manifest has.

## `image_tag` cannot find an image

Without Propshaft or Sprockets, `image_tag "logo.png"` has nothing to look it up in. Put the image in `app/javascript/images/` and use `rspack_image_tag "logo.png"` (or `rspack_asset_path "logo.png"` for the URL). Rspack fingerprints it. Or put it in `public/` and use `image_tag "/logo.png"`.

## Something else

[Open an issue](https://github.com/tungnt1203/rspack_rails/issues/new) with the output of `bin/rails rspack:doctor`, your Rails and Node.js versions, and the steps that reproduce the problem.
