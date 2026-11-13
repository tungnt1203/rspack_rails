# rspack_rails

[![Gem Version](https://img.shields.io/gem/v/rspack_rails)](https://rubygems.org/gems/rspack_rails)
[![CI](https://github.com/tungnt1203/rspack_rails/actions/workflows/main.yml/badge.svg)](https://github.com/tungnt1203/rspack_rails/actions/workflows/main.yml)

Bundle your Rails app's JavaScript and CSS with [Rspack](https://rspack.rs), the Rust-powered, webpack-compatible bundler, and get **hot module replacement** in development.

![Editing CSS and a Stimulus controller while the page keeps its state](docs/hmr.gif)

*Above: CSS and a Stimulus controller are edited while the page is open. Both update in place, and the counter keeps its value because the page never reloads.*

- **One command setup**: `bin/rails rspack:install`, then `bin/dev`
- **HMR for JavaScript, CSS and Stimulus controllers**, with an automatic fallback to the asset pipeline when the dev server is not running
- **Stimulus autoloading**: drop a `*_controller.js` (or `.ts`) in `app/javascript/controllers`, no manifest to maintain
- **TypeScript and CSS modules** out of the box, through Rspack's built-in SWC and native CSS
- **Multiple entry points** from `app/javascript/entrypoints/`
- **`rspack:migrate`** moves an importmap or jsbundling app over in one command
- **`rspack:doctor`** checks Node.js, packages, config and layout, and says what to fix
- Works with **Propshaft and Sprockets**; CI runs a real app on Rails 7.2 and 8.1

rspack_rails follows the `jsbundling-rails` model: rspack writes bundles to `app/assets/builds`, and Propshaft (or Sprockets) serves and fingerprints them in production.

## Installation

```bash
bundle add rspack_rails
bin/rails rspack:install
```

The installer:

- creates `rspack.config.mjs` and `app/javascript/application.js`
- adds `build`, `build:watch` and `dev` (`rspack serve`) scripts
- adds `rspack_javascript_tag "application"` to your layout
- adds a `js:` process running the dev server to `Procfile.dev` and sets up `bin/dev`
- installs `@rspack/cli`, `@rspack/core` and `@rspack/dev-server` with your package manager (bun, yarn, pnpm or npm, detected from the lockfile)

## Migrating from importmap or jsbundling

```bash
git commit -am "Before rspack"     # rspack:migrate refuses to run on a dirty tree (FORCE=1 to override)
bin/rails rspack:migrate
git diff                           # review
bin/dev
```

**From importmap-rails**
- Every `pin` in `config/importmap.rb` becomes an npm dependency. Versions recorded by importmap (`# @1.2.3` or jspm URLs) are kept. Gem-served pins such as Turbo install the latest npm release.
- `javascript_importmap_tags` is replaced with `rspack_javascript_tag`, and `import "controllers"` with the Stimulus autoloader.
- `config/importmap.rb`, `bin/importmap`, vendored packages, the `importmap-rails` gem, `stale_when_importmap_changes` and the `bin/importmap audit` CI step are removed.
- Bare imports of app code (`import "controllers/application"`) keep working through `resolve.modules`.

**From jsbundling-rails** (esbuild, webpack, rollup)
- The `jsbundling-rails` gem, the old bundler package and its config file are removed. `Procfile.dev` runs the rspack dev server.
- `javascript_include_tag "application"` becomes `rspack_javascript_tag`, and the generated `controllers/index.js` gives way to the autoloader.
- Extra entry files in the root of `app/javascript/` are listed so you can move them to `app/javascript/entrypoints/`.

The task finishes by listing any remaining lines that mention importmap or jsbundling. Shakapacker/Webpacker apps are not supported yet.

## Usage

Run `bin/dev` to start Rails and the rspack dev server (with hot module replacement) together.

### View helpers

```erb
<%= rspack_javascript_tag "application", "data-turbo-track": "reload" %>
<%= rspack_stylesheet_tag "application" %>
```

In development, when `rspack serve` is reachable, the helpers load bundles from the dev server (`http://localhost:3036/application.js`), so edits are hot-reloaded. Otherwise they fall back to `javascript_include_tag` / `stylesheet_link_tag`, served and fingerprinted by Propshaft from `app/assets/builds`. Production always uses the asset pipeline. `rspack_javascript_tag` adds `defer` by default.

### Dev server settings

`rspack.config.mjs` and the gem read the same environment variables, so a `.env` file (loaded by foreman) changes both:

| Variable | Default |
|---|---|
| `RSPACK_DEV_SERVER_HOST` | `localhost` |
| `RSPACK_DEV_SERVER_PORT` | `3036` |
| `RSPACK_DEV_SERVER=false` | turns the dev server check off |

Rails-side settings can also go in an initializer (this does not change `rspack.config.mjs`, so prefer env vars for host and port):

```ruby
RspackRails.configure do |config|
  config.dev_server_port = 4000
  config.dev_server_enabled = false
end
```

### Stimulus

```bash
bin/rails rspack:install:stimulus
```

This installs `@hotwired/stimulus` and adds `app/javascript/controllers/autoload.js`, imported from `application.js`. Every `*_controller.js` (or `.ts`) under `app/javascript/controllers` is registered automatically, with the usual naming (`admin/user_card_controller.js` becomes `admin--user-card`). There is no manifest to keep up to date.

Under `rspack serve`, editing a controller or adding a new one hot-swaps it in the open page without a reload, so form input and other page state survive.

If `application.js` imported `./controllers` (the stimulus-rails index), the installer switches it to `./controllers/autoload`. stimulus-rails may still rewrite `controllers/index.js` when you run `bin/rails generate stimulus`, but nothing imports that file any more.

### Multiple entry points

Besides `app/javascript/application.js` (or `.ts`), every file in `app/javascript/entrypoints/` becomes its own bundle, named after the file:

```
app/javascript/application.js           -> application.js
app/javascript/entrypoints/admin.ts     -> admin.js
app/javascript/entrypoints/checkout.js  -> checkout.js (+ checkout.bundle.css if it imports CSS)
```

```erb
<%# app/views/layouts/admin.html.erb %>
<%= rspack_javascript_tag "admin" %>
```

Each bundle is self-contained, so load one entry per page (for example one per layout). Restart the dev server after adding a new entry point.

### CSS

Import CSS from your JavaScript and rspack extracts it to `app/assets/builds/<entry>.bundle.css`:

```js
// app/javascript/application.js
import "./styles/application.css"
```

```erb
<%= rspack_stylesheet_tag "application" %>
```

`*.module.css` files are compiled as CSS modules. Under `rspack serve`, CSS changes are applied without a page reload.

The `.bundle` suffix keeps the output from clashing with `app/assets/stylesheets/application.css`. Rails 8's default `stylesheet_link_tag :app` links every CSS file under `app/assets`, so it also links the bundle. That is harmless: the dev server keeps `app/assets/builds` up to date and its own link comes later in the cascade. A rule you delete keeps applying until the next reload.

### TypeScript

`.ts` files compile out of the box with Rspack's built-in SWC loader, including Stimulus controllers (`*_controller.ts`). SWC strips types without checking them. For type checking:

```bash
bin/rails rspack:install:typescript   # tsconfig.json, typescript, "typecheck" script
npm run typecheck
```

### Tasks

| Task | What it does |
|---|---|
| `bin/rails rspack:install:stimulus` | Sets up Stimulus with controller autoloading |
| `bin/rails rspack:install:typescript` | Adds tsconfig.json, typescript and a `typecheck` script |
| `bin/rails rspack:migrate` | Moves an importmap or jsbundling app to rspack |
| `bin/rails rspack:doctor` | Checks Node.js, packages, config, layout, Procfile and dev server |
| `bin/rails rspack:build` | Installs JS dependencies, then runs `build` |
| `bin/rails rspack:clobber` | Removes rspack output from `app/assets/builds` |

`rspack:build` runs automatically before `assets:precompile`, `test:prepare`, `spec:prepare` and `db:test:prepare`. Set `SKIP_RSPACK_BUILD=1` to turn that off.

When `RAILS_ENV` or `NODE_ENV` is `production`, the generated config builds in production mode (minified). Lazy-loaded chunks are named `*.digested.js`, so Propshaft serves them without fingerprinting them a second time.

### Doctor

`bin/rails rspack:doctor` checks the setup and prints a hint for anything missing:

```
✓ Node.js: v22.12.0 (rspack needs ^20.19.0 || >=22.12.0)
✓ @rspack/core: 2.3.2
✓ Layout: uses rspack_javascript_tag
! Dev server: not running at http://localhost:3036
    → Start it with bin/dev; until then pages use app/assets/builds

0 error(s), 1 warning(s).
```

The required Node.js version comes from the `engines` field of the installed `@rspack/core`. The task exits with status 1 when there are errors, so it can run in CI.

## Development

```bash
bin/setup
bundle exec rake   # specs + rubocop
bin/integration    # new Rails app + every installer, build, doctor and precompile
bin/integration "~> 7.2.0"   # against a specific Rails version
bin/integration-migrate importmap    # rails new + rspack:migrate (or: jsbundling)
```

## License

Available under the [MIT License](https://opensource.org/licenses/MIT).
