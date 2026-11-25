# Contributing to rspack_rails

Thanks for helping. Bug reports, fixes, docs improvements and new ideas are all welcome. This page covers how to get set up, how the code is laid out and which checks to run before you open a pull request.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a bug

[Open an issue](https://github.com/tungnt1203/rspack_rails/issues/new) with:

- the output of `bin/rails rspack:doctor`
- your Ruby, Rails and Node.js versions, and your package manager
- whether the app uses Propshaft, Sprockets or neither
- the steps that reproduce the problem, and what you expected instead

A small app that shows the problem helps most. You can start one from the [demo app](https://github.com/tungnt1203/rspack_rails-demo) or from `rails new myapp -m template.rb`.

For a larger change, open an issue first so we can agree on the approach before you write the code.

## Setting up

You need Ruby 3.2 or later. The integration scripts also need Node.js 20.19+ or 22.12+, and `bin/integration-docker` needs Docker.

```bash
git clone https://github.com/tungnt1203/rspack_rails.git
cd rspack_rails
bin/setup
bundle exec rake    # specs + RuboCop
```

`bin/console` opens IRB with the gem loaded.

To try your working tree in a real app, point that app's `Gemfile` at it:

```ruby
gem "rspack_rails", path: "../rspack_rails"
```

## How the code is laid out

```
lib/
  rspack_rails.rb            Entry point; loads everything below
  rspack_rails/
    railtie.rb               Hooks into Rails: helpers, the dev server proxy, rake tasks
    helper.rb                rspack_javascript_tag, rspack_stylesheet_tag, react_component
    manifest.rb              Reads public/rspack/.rspack-manifest.json (.rspack-dev-manifest.json under rspack serve)
    static_files.rb          Serves public/rspack under /rspack/ with a far-future cache header
    dev_server.rb            Is `rspack serve` reachable?
    dev_server_proxy.rb      Proxies /rspack/* from Rails to the dev server
    configuration.rb         RspackRails.configure
    entrypoints.rb           Finds entries, mirroring rails.mjs
    installer.rb             Shared steps for the installers in lib/install
    config_installer.rb      Installs the two Rspack config files
    layout_installer.rb      Edits layouts and layout partials
    layouts.rb               Finds ERB, Slim and Haml layouts and writes helper calls
    containers.rb            Dockerfile, bin/setup and devcontainer edits
    tailwind.rb              The paths application.css leaves out of Tailwind's class scan
    migration.rb             Detects importmap or jsbundling and plans rspack:migrate
    managed_file.rb          Files the gem owns in an app (checksummed, rewritten on upgrade)
    rspack_config.rb         rspack.config.mjs and config/rspack/rails.mjs in an app
    doctor.rb                rspack:doctor: runs the check groups and prints the report
    doctor/                  The checks, in groups (packages, build, layouts, ...) over a shared Context
    package_manager.rb       Detects bun, yarn, pnpm or npm from the lockfile
    node_version.rb          Matches package.json "engines" ranges
    rspack_version.rb        The Rspack major the gem supports
    app.rb                   An app's files, as the classes above read them
  install/                   Rails application templates, one per rake task
    install.rb, migrate.rb, stimulus.rb, typescript.rb, react.rb, tailwind.rb, sass.rb
    rails.mjs                Becomes config/rspack/rails.mjs in the app
    rspack.config.mjs        Becomes the app's own rspack.config.mjs
    stimulus/, react/, ...   Files the installers copy into the app
  tasks/rspack_rails.rake    The rspack:* tasks
sig/rspack_rails.rbs         The public Ruby API (see "Stability" in docs/upgrading.md)
template.rb                  The `rails new -m` template
spec/                        RSpec unit specs, one file per class
  fixtures/doctor/           The doctor's full report for a few apps (UPDATE_GOLDEN=1 rewrites them)
bin/integration*             End-to-end checks against freshly generated Rails apps
benchmark/                   Build times of Rspack, esbuild and webpack on a generated app (not shipped in the gem)
docs/                        The user guides linked from the README
site/                        The project website, deployed to GitHub Pages
```

Things worth knowing before you change something:

- **`lib/install/rails.mjs`, `stimulus/autoload.js` and `react/mount.js` are managed files.** Apps get a copy stamped with the gem version and a checksum, and `rspack:sync` rewrites it on upgrade. A change there reaches every app on its next build, so keep it backwards compatible with apps' own `rspack.config.mjs`.
- **`lib/rspack_rails/entrypoints.rb` mirrors entry discovery in `rails.mjs`.** Change one and you change the other.
- **The installers must be safe to run twice.** Each step checks whether its work is already done before it edits a file.
- **The public API is small on purpose.** Anything listed in [Stability](docs/upgrading.md#stability) only changes in a major release, after a deprecation.

## Running the checks

`bundle exec rake` runs the unit specs and RuboCop. It is quick, and it must pass on every pull request.

The integration scripts each generate a Rails app in a temporary directory, install the gem from your working tree and check the result. They take a few minutes each, so run the one that covers your change:

| You changed | Run |
|---|---|
| An installer, `rails.mjs`, the helpers, the doctor or a rake task | `bin/integration` |
| `rspack:migrate` or the Tailwind/Sass moves | `bin/integration-migrate importmap` (or `jsbundling`, `tailwind`, `sass`) |
| TypeScript, `.ts` entries or Slim/Haml layouts | `bin/integration-typescript` |
| The dev server, the proxy, HMR or view reloads | `bin/integration-hmr` (installs Playwright and Chromium) |
| `template.rb` | `bin/integration-template skip-js` (or `importmap`) |
| Dockerfile, `bin/setup` or devcontainer edits | `bin/integration-docker` (needs Docker) |

Most scripts take a Rails version and a package manager:

```bash
bin/integration "~> 7.2.0"            # a specific Rails version
PACKAGE_MANAGER=yarn bin/integration  # or bun; Yarn is Yarn 1. Default: npm
RSPACK_VERSION=2.0 bin/integration    # the oldest supported Rspack
```

CI runs all of them on every pull request, across Ruby 3.2 to 3.4, Rails 7.2 and 8.1, and npm, yarn and bun. A weekly job also runs `bin/integration` against the newest Rspack release, prereleases included.

## Code style

- RuboCop enforces the style, including double-quoted strings. Run `bundle exec rubocop -a` to fix what it can.
- Add or update a spec for every behaviour change.
- Write comments that explain why, in plain sentences.

## Opening a pull request

1. Branch from `main`.
2. Make the change, with specs.
3. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) for anything users would notice. Say what changed and why, as the existing entries do.
4. Update the README or the guides in `docs/` when behaviour, a task or an environment variable changes.
5. Run `bundle exec rake` and the integration script that covers your change.
6. Open the pull request with what it fixes and how you tested it.

Leave the version number alone; the maintainer bumps it when cutting a release.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE.txt).
