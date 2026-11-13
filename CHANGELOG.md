## [Unreleased]

- `rspack:doctor`: checks Node.js against rspack's `engines`, packages, config, entry, build output, layout, Procfile.dev, Stimulus and the dev server
- `rspack:install:stimulus`: Stimulus with automatic controller registration and hot-swapping under `rspack serve`
- `rspack_javascript_tag` / `rspack_stylesheet_tag` helpers that load from `rspack serve` in development and fall back to the asset pipeline
- Dev server with hot module replacement (`npm run dev`), configured via `RSPACK_DEV_SERVER_*` env vars or `RspackRails.configure`
- Installer adds `@rspack/dev-server` and upgrades Phase 1 layouts and `Procfile.dev`

- Railtie with `rspack:install`, `rspack:build`, `rspack:dependencies` and `rspack:clobber` tasks
- Hook `rspack:build` into `assets:precompile` and test prepare tasks
- Package manager detection (bun, yarn, pnpm, npm)

## [0.1.0] - 2025-05-03

- Initial release
