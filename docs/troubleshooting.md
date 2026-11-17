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

`app/assets/builds` still holds the dev server's output, which loads code-split chunks from it. Run `bin/rails rspack:build`. It also runs before tests and `assets:precompile`.

## A print or admin stylesheet applies on every page

Rails 8's default `stylesheet_link_tag :app` links every CSS file under `app/assets`, including Rspack's `app/assets/builds/*.bundle.css`, without the options you gave `rspack_stylesheet_tag` (such as `media: "print"`).

`rspack:install` replaces `:app` with your own stylesheets by name. If a layout still has `:app`, list your stylesheets in its place. `rspack:doctor` warns about it.

## Sass files on Sprockets fail with a missing `sassc` gem

Sprockets, the Rails 7 default, compiles any `.scss` file under `app/assets/stylesheets` itself, through `require_tree .` and `link_directory`. Keep Sass files in `app/javascript` instead. Partials in `app/javascript/stylesheets` load with `@use "stylesheets/variables"`.

## Something else

[Open an issue](https://github.com/tungnt1203/rspack_rails/issues/new) with the output of `bin/rails rspack:doctor`, your Rails and Node.js versions, and the steps that reproduce the problem.
