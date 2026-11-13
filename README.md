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
- adds `build` and `build:watch` scripts to `package.json`
- adds `javascript_include_tag "application"` to your layout
- adds a `js:` process to `Procfile.dev` and sets up `bin/dev`
- installs `@rspack/cli` and `@rspack/core` with your package manager (bun, yarn, pnpm or npm, detected from the lockfile)

## Usage

Run `bin/dev` to start Rails and `rspack build --watch` together.

| Task | What it does |
|---|---|
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
