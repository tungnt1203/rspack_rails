# rspack_rails

[![Gem Version](https://img.shields.io/gem/v/rspack_rails)](https://rubygems.org/gems/rspack_rails)
[![CI](https://github.com/tungnt1203/rspack_rails/actions/workflows/main.yml/badge.svg)](https://github.com/tungnt1203/rspack_rails/actions/workflows/main.yml)

Bundle your Rails app's JavaScript and CSS with [Rspack](https://rspack.rs), the Rust-powered, webpack-compatible bundler, with **hot module replacement** in development and fingerprinted files that Rails serves itself in production.

![Editing a view and a Stimulus controller in the rspack_rails demo app](docs/hmr.gif)

*In the [demo app](https://github.com/tungnt1203/rspack_rails-demo): a Tailwind class added to an ERB view shows up after an automatic reload, then an edited Stimulus controller is swapped in place without one.*

The [demo app](https://github.com/tungnt1203/rspack_rails-demo) also runs [live](https://52-65-113-251.sslip.io): React, CSS modules in Sass, lazy chunks, a Web Worker, Turbo Streams over Action Cable and a page with its own bundle, deployed with Kamal.

## Quick start

**A new app**

```bash
rails new myapp -m https://raw.githubusercontent.com/tungnt1203/rspack_rails/main/template.rb
cd myapp
bin/dev
```

That writes one `rspack.config.mjs`, which is yours. Add Sass, Tailwind CSS, React, TypeScript or Stimulus the way you would in any Rspack project: a package and a few lines of config ([Adding tools](docs/guide.md#adding-tools)).

**An existing app**

```bash
bundle add rspack_rails
bin/rails rspack:install
bin/dev
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

- **Hot updates in development.** CSS is swapped in place, and so are the JavaScript modules that accept hot updates: Stimulus controllers as the [guide](docs/guide.md#stimulus) sets them up, React components with Fast Refresh. Any other JavaScript edit reloads the page. It all goes through Rails, with no second origin to configure, and editing a view reloads the page.
- **No asset pipeline to configure.** Rspack fingerprints its files into `public/rspack`, and Rails serves them with a far-future cache header. Propshaft and Sprockets are not needed (and still work for the rest of your assets).
- **One config file, yours.** `rspack.config.mjs` is a plain Rspack config with the Rails parts commented. Nothing is generated behind it and nothing is rewritten on upgrade.
- **Images for views.** `rspack_image_tag "logo.svg"` for files in `app/javascript/images`, fingerprinted, without Propshaft.
- **TypeScript, CSS modules, images and fonts** work out of the box; Sass, Tailwind CSS, React and Stimulus are a package and a few lines of config ([Adding tools](docs/guide.md#adding-tools)).
- **A doctor.** `bin/rails rspack:doctor` checks Node.js, packages, config, layouts, `bin/dev` and the Docker setup, and says what to fix ([the list](docs/production.md#doctor)).
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
- **Dev server stopped:** the helpers link the last `bin/rails rspack:build` in `public/rspack`.
- **Production:** `rspack:build` runs before `assets:precompile` (the task exists without Propshaft or Sprockets too), and Rails serves `public/rspack` under `/rspack/`.

## Documentation

| Guide | What's in it |
|---|---|
| [Usage](docs/guide.md) | Entry points, `#/` imports, CSS, images and fonts, and how to add TypeScript, Stimulus, Sass, Tailwind CSS or React |
| [Recipes](docs/recipes.md) | Environment values, aliases, Less, PostCSS, Vue, Svelte, Preact, jQuery globals and built-in plugins |
| [Production](docs/production.md) | Builds, source maps, Subresource Integrity, Docker and Kamal, dev containers, bundle analysis |
| [Configuration](docs/configuration.md) | Customizing `rspack.config.mjs`, environment variables, every rake task |
| [Migrating](docs/migrating.md) | Moving from importmap-rails or jsbundling-rails |
| [Upgrading](docs/upgrading.md) | Updating the gem, and what stays stable from 1.0 |
| [Troubleshooting](docs/troubleshooting.md) | Common errors and what to do about them |

How fast is it? [Rails + Rspack: esbuild speed, webpack features, one command](https://dev.to/tungnt1203/rails-rspack-esbuild-speed-webpack-features-one-command-4652) compares Rspack with esbuild and webpack; [`benchmark/`](benchmark) has the script to run it yourself.

[rspack_rails-demo](https://github.com/tungnt1203/rspack_rails-demo) is a Rails 8 app with TypeScript Stimulus controllers, Tailwind CSS, code splitting and a second entry point. Its git history has one commit per installer, so you can see exactly what each one changes.

## Requirements

- Ruby 3.2+ and Rails 7.2+ (with or without Propshaft or Sprockets)
- Node.js 20.19+ or 22.12+
- bun, yarn, pnpm or npm, detected from your lockfile
- Rspack 2, installed for you

## Contributing

Bug reports, fixes and docs improvements are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers setting up, finding your way around the code and which tests to run for which change. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Available under the [MIT License](LICENSE.txt).
