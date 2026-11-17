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
- `javascript_importmap_tags` is replaced with `rspack_javascript_tag` in each layout or layout partial that called it, and `import "controllers"` with the [Stimulus autoloader](guide.md#stimulus).
- `config/importmap.rb`, `bin/importmap`, vendored packages, the `importmap-rails` gem, `stale_when_importmap_changes` and the `bin/importmap audit` CI step are removed.
- Bare imports of app code (`import "controllers/application"`) keep working through `resolve.modules`.

## From jsbundling-rails

For esbuild, webpack and rollup setups.

- The `jsbundling-rails` gem, the old bundler package and its config file are removed. `Procfile.dev` runs the Rspack dev server.
- `javascript_include_tag "application"` becomes `rspack_javascript_tag`, and the generated `controllers/index.js` gives way to the autoloader.
- Extra entry files in the root of `app/javascript/` are listed so you can move them to `app/javascript/entrypoints/`.

## From tailwindcss-rails

This is what `rails new --css tailwind` sets up. Run `bin/rails rspack:migrate` first, then:

```bash
bin/rails rspack:install:tailwind
```

It moves `app/assets/tailwind/application.css` (with your `@theme`, `@plugin` and `@source` lines), and the other CSS files next to it, to `app/javascript/`. It also removes the gem, the `css:` line in `Procfile.dev` and the old `tailwind.css` build.

## From dartsass-rails

This is what `rails new --css sass` sets up. Run `bin/rails rspack:migrate` first, then:

```bash
bin/rails rspack:install:sass
```

It imports `app/assets/stylesheets/application.scss` where it is, so its partials keep working, and removes the gem, the `css:` line in `Procfile.dev` and the old build. If you had custom builds in `config/initializers/dartsass.rb`, import each of those files from JavaScript.

## A new app with `rails new` options

`template.rb` works with any `rails new` options. The default importmap setup is migrated to Rspack, and `--css tailwind` or `--css sass` are moved over for you.
