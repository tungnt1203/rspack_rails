# Production

[Back to the README](../README.md)

- [Builds](#builds)
- [Subresource Integrity](#subresource-integrity)
- [Deploying (Docker and Kamal)](#deploying-docker-and-kamal)
- [Dev containers](#dev-containers)
- [Bundle analysis](#bundle-analysis)
- [Doctor](#doctor)

## Builds

`rspack:build` runs automatically before `assets:precompile`, `test:prepare`, `spec:prepare` and `db:test:prepare`. Set `RSPACK_SKIP_BUILD=1` to turn that off. It installs JavaScript dependencies first, then runs the `build` script with `NODE_ENV` set from `Rails.env`: `development` in development and test, `production` everywhere else.

- **Production mode.** When `RAILS_ENV` or `NODE_ENV` is `production`, the generated config minifies.
- **Output.** Builds write to `public/rspack`, every file named with a fingerprint (`application-1a2b3c4d.js`, chunks, images and fonts too), and Rails serves them under `/rspack/` with `Cache-Control: public, max-age=31536000, immutable`. No asset pipeline is involved, so `app/assets` keeps whatever Propshaft or Sprockets does with it. With a web server in front that serves `public/` itself, give `/rspack/` the same header there.
- **Browser targets.** JavaScript and CSS are compiled for the browsers in your [browserslist](https://github.com/browserslist/browserslist) config (`.browserslistrc`, or `"browserslist"` in `package.json`). Without one, the target is Baseline "widely available", which matches Rails 8's `allow_browser versions: :modern`.
- **Source maps.** On in development (`cheap-module-source-map`), off in production, so your source never ships in `public/rspack`. `RSPACK_DEVTOOL` picks another [devtool](https://rspack.rs/config/devtool), for example `hidden-source-map` to upload maps to an error tracker.
- **Old builds.** A build keeps the files of the last 3 builds (`RSPACK_KEEP_BUILDS=5` keeps more) and deletes everything else in `public/rspack`, so a page loaded before a deploy still finds its chunks while servers roll over, and precompiling on a machine that ran development builds ships none of its leftovers. Only `rspack_rails` writes to that directory. Only builds of the same mode count, so a production build never ships a development build's source maps. A build identical to the last one counts once.
- **Lazy compilation.** Under `rspack serve`, dynamic `import()`s are compiled the first time the page asks for them, which keeps startup fast in large apps. The request goes to `/rspack/_rspack/lazy/trigger` on the page's own origin, which Rails proxies to the dev server.
- **Persistent cache.** Kept in `node_modules/.cache/rspack`. Editing `rspack.config.mjs`, `config/rspack/rails.mjs`, `package.json`, the lockfile, `tsconfig.json` or `.browserslistrc` starts a fresh cache. Delete the directory to clear it by hand.

## Subresource Integrity

Pass `integrity: true` to have the browser check each bundle against a hash, so a tampered file on a CDN does not run:

```erb
<%= rspack_javascript_tag "application", integrity: true %>
<%= rspack_stylesheet_tag "application", integrity: true %>
```

The helpers hash each file with SHA-384 (and add `crossorigin="anonymous"`, which the browser needs to check a file from another origin). Nothing to configure.

- The attribute is never added for files from `rspack serve`, which rewrites them on every change.
- Only the files linked by the helpers are covered. Chunks that Rspack loads at runtime (dynamic `import()`, Web Workers) get no hash. Rspack's own `SubresourceIntegrityPlugin` covers those too, if you need it.

## Deploying (Docker and Kamal)

`assets:precompile` runs `rspack:build` (rspack_rails defines the task when there is no Propshaft or Sprockets), so the image needs Node.js at build time. Rails only adds Node.js to the `Dockerfile` for apps created with a JavaScript bundler, so `rspack:install` adds it to the build stage:

- Node.js (the version you run locally, or `NODE_VERSION`), installed the same way Rails does for esbuild apps.
- `COPY package.json package-lock.json` and `npm ci` (or your package manager's frozen install) before the app is copied, so the layer is cached.
- `RUN rm -rf node_modules` after precompiling, so the final image ships the built assets and no Node.js or node modules.

`rspack:doctor` reports a `Dockerfile` that cannot run Rspack. CI builds and runs the image of a new app.

**Rolling deploys.** A page loaded before a deploy asks for the old build's chunks, which a new container does not have. Kamal's asset bridging copies them over: set `asset_path: /rails/public/rspack` in `config/deploy.yml`. The old files stay there while `RSPACK_KEEP_BUILDS` builds of them exist.

## Dev containers

In an app made with `rails new --devcontainer`, `rspack:install` adds the `ghcr.io/devcontainers/features/node` feature to `.devcontainer/devcontainer.json` and forwards port 3036 next to 3000. Pages come through Rails, but the browser opens the HMR websocket to the dev server directly. `bin/setup`, which the container runs on creation, installs node modules. Rebuild the container after installing.

When the browser cannot reach the dev server at `localhost:3036`, set `RSPACK_DEV_SERVER_PUBLIC_URL` to the dev server's URL as the browser sees it. `https://` becomes `wss://`, and `/ws` is added when the URL has no path. GitHub Codespaces, for example, serves each port on its own URL:

```bash
# Make port 3036 visible to the browser in Codespaces first
export RSPACK_DEV_SERVER_HOST=0.0.0.0
export RSPACK_DEV_SERVER_PUBLIC_URL="https://$CODESPACE_NAME-3036.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"
bin/dev
```

The same goes for a dev server behind a TLS proxy. Only the websocket uses this URL; scripts and chunks still come through Rails. CI checks that the browser connects to the public URL while the dev server listens on `0.0.0.0`. Codespaces itself is not tested.

## Bundle analysis

```bash
bin/rails rspack:analyze
```

This runs a production build into `tmp/rsdoctor/build` (leaving `public/rspack` alone) and writes a single-file [Rsdoctor](https://rsdoctor.rs) report to `tmp/rsdoctor/rsdoctor-report.html`, with bundle and module sizes, duplicate packages and build timings. It installs `@rsdoctor/rspack-plugin` the first time.

Builds do not print Rspack's size hints, which flag every entry over 244 KiB (an app with React and Turbo starts above it). To have a build warn or fail over a budget of your own, set `performance` in `rspack.config.mjs`:

```js
export default railsConfig((config) => {
  config.performance = { hints: "error", maxEntrypointSize: 400_000, maxAssetSize: 400_000 };
});
```

## Doctor

`bin/rails rspack:doctor` checks the setup and prints a hint for anything missing:

```
✓ Node.js: v22.12.0 (rspack needs ^20.19.0 || >=22.12.0)
✓ @rspack/core: 2.3.2
✓ Layout: uses rspack_javascript_tag
! Dev server: not running at http://localhost:3036
    → Start it with bin/dev; until then pages use the last bin/rails rspack:build in public/rspack

0 error(s), 1 warning(s).
```

The task exits with status 1 when there are errors, so it can run in CI.
