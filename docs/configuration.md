# Configuration

[Back to the README](../README.md)

- [The Rspack config](#the-rspack-config)
- [Environment variables](#environment-variables)
- [Ruby configuration](#ruby-configuration)
- [Rake tasks](#rake-tasks)

## The Rspack config

`rspack.config.mjs` is the only config file, and it is yours: `bin/rails rspack:install` writes it once, and rspack_rails never rewrites it. It is an ordinary [Rspack config](https://rspack.rs/config) with a few settings the Rails side depends on, each commented in the file:

- `output.path` is `public/rspack`, with fingerprinted file names, and `output.clean` empties it before each build.
- `manifestPlugin()` at the bottom writes `public/rspack/.rspack-manifest.json`, which the view helpers read (`.rspack-dev-manifest.json` under `rspack serve`). `imagesPlugin()` adds the images of `app/javascript/images` to it.
- The `devServer` block keeps files in memory, serves them through Rails under `/rspack/`, and reads its host and port from the environment.

Change anything else as you would in any Rspack project: add a loader, an alias, a plugin, an entry.

```js
import { rspack } from "@rspack/core";

// in the config
resolve: { alias: { "~": path.resolve(root, "app/javascript") } },
plugins: [new rspack.DefinePlugin({ __SENTRY_ENABLED__: isProduction }), imagesPlugin(), manifestPlugin()],
```

`rspack:doctor` checks that the config still writes the manifest. To see what a newer rspack_rails would generate, copy `lib/install/rspack.config.mjs` from the gem (or `rails new` an app) and compare.

## Environment variables

`rspack.config.mjs` and the gem read the same environment variables, so a `.env` file (loaded by foreman) changes both.

| Variable | Default | Effect |
|---|---|---|
| `RSPACK_DEV_SERVER_HOST` | `localhost` | Dev server host |
| `RSPACK_DEV_SERVER_PORT` | `3036` | Dev server port |
| `RSPACK_DEV_SERVER_PUBLIC_URL` | `http://<host>:<port>` | Where the browser opens the HMR websocket, for forwarded ports and TLS proxies ([Dev containers](production.md#dev-containers)) |
| `RSPACK_DEV_SERVER` | | `false` turns the dev server check off; the helpers always use the last build in `public/rspack` |
| `NODE_VERSION` | the local `node --version` | Node.js version `rspack:install` writes into the `Dockerfile` |
| `RSPACK_SKIP_BUILD` | | Any value stops `rspack:build` from running before `assets:precompile` and test tasks |
| `RSPACK_FORCE` | | `1` lets `rspack:migrate` run on a dirty git tree |

## Ruby configuration

To decide in Ruby whether pages use the dev server, use an initializer:

```ruby
# config/initializers/rspack_rails.rb
RspackRails.configure do |config|
  config.dev_server_enabled = false # pages always use the last build in public/rspack
end
```

The dev server's host and port come only from `RSPACK_DEV_SERVER_HOST` and `RSPACK_DEV_SERVER_PORT`, which Rails and `rspack serve` both read, so the two never disagree.

Deprecations go through `Rails.application.deprecators`, so `config.active_support.deprecation` decides whether they warn, log or raise.

## Rake tasks

| Task | What it does |
|---|---|
| `bin/rails rspack:install` | Sets up Rspack: config, entry, scripts, layout tags, `Procfile.dev` |
| `bin/rails rspack:migrate` | Moves an importmap or jsbundling app to Rspack |
| `bin/rails rspack:build` | Installs JavaScript dependencies, then runs `build` |
| `bin/rails rspack:clobber` | Removes `public/rspack` (also runs with `assets:clobber`) |
| `bin/rails rspack:doctor` | Checks Node.js, packages, config, build output, layout, `bin/dev`, `Procfile.dev`, the dev server, and a Dockerfile or dev container if there is one ([what it checks](production.md#doctor)) |
