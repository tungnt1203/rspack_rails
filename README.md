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

This installs `@hotwired/stimulus` and adds `app/javascript/controllers/autoload.js`, imported from `application.js`. Every `*_controller.js` under `app/javascript/controllers` is registered automatically, with the usual naming (`admin/user_card_controller.js` becomes `admin--user-card`). There is no manifest to keep up to date.

Under `rspack serve`, editing a controller or adding a new one hot-swaps it in the open page without a reload, so form input and other page state survive.

If `application.js` imported `./controllers` (the stimulus-rails index), the installer switches it to `./controllers/autoload`. stimulus-rails may still rewrite `controllers/index.js` when you run `bin/rails generate stimulus`, but nothing imports that file any more.

### Tasks

| Task | What it does |
|---|---|
| `bin/rails rspack:install:stimulus` | Sets up Stimulus with controller autoloading |
| `bin/rails rspack:build` | Installs JS dependencies, then runs `build` |
| `bin/rails rspack:clobber` | Removes rspack output from `app/assets/builds` |

`rspack:build` runs automatically before `assets:precompile`, `test:prepare`, `spec:prepare` and `db:test:prepare`. Set `SKIP_RSPACK_BUILD=1` to turn that off.

When `RAILS_ENV` or `NODE_ENV` is `production`, the generated config builds in production mode (minified). Lazy-loaded chunks are named `*.digested.js`, so Propshaft serves them without fingerprinting them a second time.

## Development

```bash
bin/setup
bundle exec rake   # specs + rubocop
```

## License

Available under the [MIT License](https://opensource.org/licenses/MIT).
