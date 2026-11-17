# rspack_rails

[![Gem Version](https://img.shields.io/gem/v/rspack_rails)](https://rubygems.org/gems/rspack_rails)
[![CI](https://github.com/tungnt1203/rspack_rails/actions/workflows/main.yml/badge.svg)](https://github.com/tungnt1203/rspack_rails/actions/workflows/main.yml)

Bundle your Rails app's JavaScript and CSS with [Rspack](https://rspack.rs), the Rust-powered, webpack-compatible bundler, with **hot module replacement** in development and the asset pipeline in production.

![Editing a view and a Stimulus controller in the rspack_rails demo app](docs/hmr.gif)

*In the [demo app](https://github.com/tungnt1203/rspack_rails-demo): a Tailwind class added to an ERB view shows up after an automatic reload, then an edited Stimulus controller is swapped in place without one.*

## Quick start

**A new app**

```bash
rails new myapp -m https://raw.githubusercontent.com/tungnt1203/rspack_rails/main/template.rb
cd myapp
bin/dev
```

The template asks which extras you want (Stimulus, TypeScript, React, Tailwind CSS, Sass). To skip the questions: `RSPACK_FEATURES=stimulus,typescript,tailwind rails new myapp -m …`

**An existing app**

```bash
bundle add rspack_rails
bin/rails rspack:install
bin/dev
```

Then add only what you need:

```bash
bin/rails rspack:install:stimulus     # Stimulus, with controller autoloading
bin/rails rspack:install:typescript   # type checking (TypeScript already compiles)
bin/rails rspack:install:react        # React, with Fast Refresh
bin/rails rspack:install:tailwind     # Tailwind CSS v4
bin/rails rspack:install:sass         # Sass
```

**An app on importmap-rails or jsbundling-rails**

```bash
git commit -am "Before rspack"   # rspack:migrate needs a clean tree
bin/rails rspack:migrate
git diff
bin/dev
```

See [Migrating](docs/migrating.md) for what changes.

## What you get

- **Hot updates in development.** JavaScript, CSS, Stimulus controllers and React components are swapped in place. Editing a view reloads the page.
- **The asset pipeline in production.** Rspack writes to `app/assets/builds`, and Propshaft or Sprockets fingerprints and serves the files, as `jsbundling-rails` does.
- **No manifests to maintain.** Stimulus controllers and React components are found by file name.
- **TypeScript, CSS modules, Tailwind CSS v4, Sass**, plus images and fonts imported from JavaScript or CSS.
- **A doctor.** `bin/rails rspack:doctor` checks Node.js, packages, config and layouts, and says what to fix.
- **Deploys that work.** The installer sets up the `Dockerfile` for Kamal, `bin/setup` and dev containers.

## How it works

```
            page + /rspack/*                 /rspack/* (proxied)
browser  ───────────────────▶  Rails :3000  ────────────────────▶  rspack serve :3036
   │                                                                      ▲
   └───────────────────────────── HMR websocket ──────────────────────────┘
```

Put two helpers in your layout:

```erb
<%= rspack_javascript_tag "application", "data-turbo-track": "reload" %>
<%= rspack_stylesheet_tag "application" %>
```

- **`bin/dev` running:** the helpers point at `/rspack/…`, and Rails proxies those requests to `rspack serve`. Only the HMR websocket goes to the dev server directly.
- **Dev server stopped:** the helpers fall back to the last build in `app/assets/builds`.
- **Production:** `rspack:build` runs before `assets:precompile`, and the asset pipeline serves the result.

## Documentation

| Guide | What's in it |
|---|---|
| [Usage](docs/guide.md) | Entry points, `#/` imports, Stimulus, CSS, Tailwind, Sass, React, TypeScript, images and fonts |
| [Production](docs/production.md) | Builds, source maps, Subresource Integrity, Docker and Kamal, dev containers, bundle analysis |
| [Configuration](docs/configuration.md) | Customizing `rspack.config.mjs`, environment variables, every rake task |
| [Migrating](docs/migrating.md) | Moving from importmap-rails, jsbundling-rails, tailwindcss-rails or dartsass-rails |
| [Upgrading](docs/upgrading.md) | Updating the gem, and what stays stable from 1.0 |
| [Troubleshooting](docs/troubleshooting.md) | Common errors and what to do about them |

[rspack_rails-demo](https://github.com/tungnt1203/rspack_rails-demo) is a Rails 8 app with TypeScript Stimulus controllers, Tailwind CSS, code splitting and a second entry point. Its git history has one commit per installer, so you can see exactly what each one changes.

## Requirements

- Ruby 3.2+ and Rails 7.2+ (Propshaft or Sprockets)
- Node.js 20.19+ or 22.12+
- bun, yarn, pnpm or npm, detected from your lockfile
- Rspack 2, installed for you

## Contributing

Bug reports, fixes and docs improvements are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers setting up, finding your way around the code and which tests to run for which change. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Available under the [MIT License](LICENSE.txt).
