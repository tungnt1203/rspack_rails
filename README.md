# rspack_rails

Bundle your Rails app's JavaScript with [Rspack](https://rspack.rs), the Rust-powered, webpack-compatible bundler.

rspack_rails follows the `jsbundling-rails` model: rspack writes bundles to `app/assets/builds`, and Propshaft (or Sprockets) serves and fingerprints them.

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
```

## License

Available under the [MIT License](https://opensource.org/licenses/MIT).
