# Migrating

[Back to the README](../README.md)

`rspack:migrate` moves an app from importmap-rails or jsbundling-rails to Rspack in one command:

```bash
git commit -am "Before rspack"   # rspack:migrate refuses to run on a dirty tree (RSPACK_FORCE=1 to override)
bin/rails rspack:migrate
git diff                         # review what changed
bin/dev
```

When it finishes, it lists any remaining lines that mention importmap or jsbundling, so you can check them by hand.

Shakapacker and Webpacker apps are not supported.

## From importmap-rails

- Every `pin` in `config/importmap.rb` becomes an npm dependency. Versions recorded by importmap (`# @1.2.3` or jspm URLs) are kept. Gem-served pins such as Turbo install the latest npm release.
- `javascript_importmap_tags` is replaced with `rspack_javascript_tag` in each layout or layout partial that called it, and the generated `controllers/index.js`, which needs importmap's `stimulus-loading`, with one that registers the controllers through Rspack ([Stimulus](guide.md#stimulus)).
- `config/importmap.rb`, `bin/importmap`, vendored packages, the `importmap-rails` gem, `stale_when_importmap_changes` and the `bin/importmap audit` CI step are removed.
- Bare imports of app code (`import "controllers/application"`) keep working through `resolve.modules`.

## From jsbundling-rails

For esbuild, webpack and rollup setups.

- The `jsbundling-rails` gem, the old bundler package and its config file are removed. `Procfile.dev` runs the Rspack dev server.
- `javascript_include_tag "application"` becomes `rspack_javascript_tag`.
- Extra entry files in the root of `app/javascript/` are listed so you can move them to `app/javascript/entrypoints/`.

## Sass and Tailwind CSS

`rails new --css sass` and `--css tailwind` set up dartsass-rails and tailwindcss-rails, which `rspack:migrate` leaves alone: they build CSS into `app/assets/builds`, which Propshaft or Sprockets keep serving. To bundle the CSS with Rspack instead, remove the gem and its `css:` line in `Procfile.dev`, then add Sass or Tailwind to `rspack.config.mjs` ([Adding tools](guide.md#adding-tools)).

## A new app with `rails new`

`template.rb` works with any `rails new` options. The default importmap setup is migrated to Rspack; add Sass, Tailwind, React or TypeScript afterwards ([Adding tools](guide.md#adding-tools)).
