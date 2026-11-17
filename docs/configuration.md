# Configuration

[Back to the README](../README.md)

- [Customizing the Rspack config](#customizing-the-rspack-config)
- [Environment variables](#environment-variables)
- [Ruby configuration](#ruby-configuration)
- [Rake tasks](#rake-tasks)

## Customizing the Rspack config

The config comes in two files:

| File | Owner | Edit it? |
|---|---|---|
| `rspack.config.mjs` | You | Yes. Upgrading the gem never touches it. |
| `config/rspack/rails.mjs` | rspack_rails | No. Commit it, but leave it alone. |

`config/rspack/rails.mjs` holds the defaults described in these docs. `rspack:build` (which runs before `assets:precompile` and tests) rewrites it whenever the gem version changes, and `bin/rails rspack:sync` does so on demand. A checksum in the file tells hand edits apart: `rspack:doctor` warns about them, and the next rewrite saves them to `tmp/rspack_rails/` before replacing them.

`rspack.config.mjs` passes a callback to `railsConfig`, which receives the full config and can change anything in it:

```js
import path from "node:path";
import { rspack } from "@rspack/core";
import { railsConfig } from "./config/rspack/rails.mjs";

export default railsConfig((config, { root, isDevServer, isProduction }) => {
  config.resolve.alias = { "~": path.resolve(root, "app/javascript") };
  config.plugins.push(new rspack.DefinePlugin({ __SENTRY_ENABLED__: isProduction }));
  config.module.rules.push({ test: /\.md$/, type: "asset/source" });
  return config; // or change it in place and return nothing
});
```

**What you can rely on.** `railsConfig` and the second argument of its callback, `{ root, isDevServer, isProduction, analyze }`, stay stable across releases. The rest of the base config can change in any release: rule order, the plugin list, other exports of `config/rspack/rails.mjs`. So find a rule by what it matches, not by its index:

```js
const sassRule = config.module.rules.find((rule) => String(rule.test).includes("scss"));
```

When Rspack runs on its own (`bin/dev`, `npm run build`) with a `config/rspack/rails.mjs` from another version than `Gemfile.lock`, it prints a warning telling you to run `rspack:sync`.

## Environment variables

`rspack.config.mjs` and the gem read the same environment variables, so a `.env` file (loaded by foreman) changes both.

| Variable | Default | Effect |
|---|---|---|
| `RSPACK_DEV_SERVER_HOST` | `localhost` | Dev server host |
| `RSPACK_DEV_SERVER_PORT` | `3036` | Dev server port |
| `RSPACK_DEV_SERVER_PUBLIC_URL` | `http://<host>:<port>` | Where the browser opens the HMR websocket, for forwarded ports and TLS proxies ([Dev containers](production.md#dev-containers)) |
| `RSPACK_DEV_SERVER` | | `false` turns the dev server check off; the helpers always use `app/assets/builds` |
| `RSPACK_DEVTOOL` | `cheap-module-source-map` in development, off in production | Source map [devtool](https://rspack.rs/config/devtool); `false` turns maps off |
| `RSPACK_LAZY_COMPILATION` | on under `rspack serve` | `false` compiles every dynamic `import()` upfront |
| `RSPACK_VIEW_RELOAD` | on under `rspack serve` | `false` stops reloading the page when `app/views`, `app/helpers` or `app/components` change |
| `RSPACK_REACT_COMPILER` | off | `true` enables the React Compiler |
| `NODE_VERSION` | the local `node --version` | Node.js version `rspack:install` writes into the `Dockerfile` |
| `RSPACK_SKIP_BUILD` | | Any value stops `rspack:build` from running before `assets:precompile` and test tasks |
| `RSPACK_FORCE` | | `1` lets `rspack:migrate` run on a dirty git tree |
| `RSPACK_FEATURES` | | For `template.rb`: the extras to install without asking, such as `stimulus,typescript,tailwind` |

## Ruby configuration

To decide in Ruby whether pages use the dev server, use an initializer:

```ruby
# config/initializers/rspack_rails.rb
RspackRails.configure do |config|
  config.dev_server_enabled = false # pages always use app/assets/builds
end
```

The dev server's host and port come only from `RSPACK_DEV_SERVER_HOST` and `RSPACK_DEV_SERVER_PORT`, which Rails and `rspack serve` both read, so the two never disagree.

Deprecations go through `Rails.application.deprecators`, so `config.active_support.deprecation` decides whether they warn, log or raise.

## Rake tasks

| Task | What it does |
|---|---|
| `bin/rails rspack:install` | Sets up Rspack: config, entry, scripts, layout tag, `Procfile.dev` |
| `bin/rails rspack:install:stimulus` | Sets up Stimulus with controller autoloading |
| `bin/rails rspack:install:typescript` | Adds `tsconfig.json`, `typescript` and a `typecheck` script |
| `bin/rails rspack:install:react` | Sets up React with Fast Refresh and `react_component` |
| `bin/rails rspack:install:tailwind` | Sets up Tailwind CSS v4, migrating from tailwindcss-rails |
| `bin/rails rspack:install:sass` | Sets up Sass, migrating from dartsass-rails |
| `bin/rails rspack:migrate` | Moves an importmap or jsbundling app to Rspack |
| `bin/rails rspack:build` | Updates `config/rspack/rails.mjs`, installs JavaScript dependencies, then runs `build` |
| `bin/rails rspack:sync` | Updates `config/rspack/rails.mjs`, and the Stimulus and React loaders if installed, to this version of rspack_rails |
| `bin/rails rspack:clobber` | Removes Rspack output from `app/assets/builds`, leaving other tools' files alone (also runs with `assets:clobber`) |
| `bin/rails rspack:doctor` | Checks Node.js, packages, config, layout, `Procfile.dev` and the dev server |
| `bin/rails rspack:analyze` | Writes an Rsdoctor bundle report to `tmp/rsdoctor/rsdoctor-report.html` |
