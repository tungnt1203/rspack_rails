# Troubleshooting

[Back to the README](../README.md)

Start with `bin/rails rspack:doctor`. It covers the usual setup mistakes and says what to fix.

## `export 'foo' (imported as 'foo') was not found` fails the build

Since Rspack 2, importing a name that a module does not export is an error, not a warning. It often shows up after migrating from importmap, where the browser only failed when the code ran.

Fix the import, or turn it back into a warning in `rspack.config.mjs`:

```js
config.module.parser = { ...config.module.parser, javascript: { exportsPresence: "warn" } };
```

## Pages load old code after I stop the dev server

`public/rspack` holds the last `bin/rails rspack:build`, which is what pages link while the dev server is stopped. Run `bin/rails rspack:build` to refresh it. It also runs before tests and `assets:precompile`.

## `rspack has no entry named "application"`

No build lists that entry yet. Start the dev server with `bin/dev`, or run `bin/rails rspack:build`. For a new file in `app/javascript/entrypoints/`, restart the dev server. The message names the entries the manifest has.

## A stylesheet from the old `app/assets/builds` is linked twice

rspack_rails 1.x built into `app/assets/builds`, where Rails 8's `stylesheet_link_tag :app` still finds the files. Run `bin/rails rspack:clobber`, then `bin/rails rspack:build`. `rspack:doctor` warns about it.

## `image_tag` cannot find an image

Without Propshaft or Sprockets, `image_tag "logo.png"` has nothing to look it up in. Import the image from JavaScript or CSS (Rspack fingerprints it), or put it in `public/` and use `image_tag "/logo.png"`.

## Sass files on Sprockets fail with a missing `sassc` gem

Sprockets, the Rails 7 default, compiles any `.scss` file under `app/assets/stylesheets` itself, through `require_tree .` and `link_directory`. Keep Sass files in `app/javascript` instead. Partials in `app/javascript/stylesheets` load with `@use "stylesheets/variables"`.

## Something else

[Open an issue](https://github.com/tungnt1203/rspack_rails/issues/new) with the output of `bin/rails rspack:doctor`, your Rails and Node.js versions, and the steps that reproduce the problem.
