# Upgrading

[Back to the README](../README.md)

## Updating the gem

```bash
bundle update rspack_rails
bin/rails rspack:sync      # or let the next rspack:build do it
bin/rails rspack:doctor
```

These files follow the gem, and `rspack:sync` rewrites them:

- `config/rspack/rails.mjs`
- `app/javascript/controllers/autoload.js`, once `rspack:install:stimulus` has run
- `app/javascript/components/mount.js`, once `rspack:install:react` has run

Your `rspack.config.mjs` is left alone. Commit them all.

Some releases also change other files (`Dockerfile`, `bin/setup`). The [CHANGELOG](../CHANGELOG.md) says when to run `bin/rails rspack:install` again. Running it again is safe: it leaves your config, entry, layouts and `Procfile.dev` alone when they are already set up.

### From 1.x to 2.0

2.0 builds into `public/rspack` and no longer goes through Propshaft or Sprockets. The view helpers are the same, so layouts need no change.

```bash
bundle update rspack_rails
bin/rails rspack:clobber   # removes the 1.x output in app/assets/builds
bin/rails rspack:build     # rewrites config/rspack/rails.mjs, builds into public/rspack
bin/rails rspack:doctor
```

What changes:

- **Output.** Rspack writes `public/rspack/<entry>-<hash>.js` and `.css`, and Rails serves it under `/rspack/` with a far-future cache header. Add `/public/rspack` to `.gitignore` and `.dockerignore` (`bin/rails rspack:install` does it; `rspack:doctor` checks `.gitignore`). `app/assets/config/manifest.js` no longer needs `//= link_tree ../builds`.
- **Propshaft and Sprockets are optional.** Keep them for the rest of `app/assets`. Without them, `assets:precompile` still runs `rspack:build`. `image_tag "logo.png"` needs one of them. Without, move the image to `app/javascript/images/` and use `rspack_image_tag "logo.png"`, or put it in `public/`.
- **`stylesheet_link_tag :app`** no longer links rspack's CSS, so a layout that has it is fine as it is. The 1.x installers replaced it with your stylesheets by name; that is no longer needed.
- **Integrity.** `integrity: true` works with no setting (`config.assets.integrity_hash_algorithm` has no effect on rspack's files).
- **Old builds.** A build keeps the files of the last 3 builds of its mode and deletes the rest of `public/rspack` (for deploys that build in place). Deploying with Kamal: set `asset_path: /rails/public/rspack`, which keeps old chunks for pages loaded before a deploy.
- **Missing builds raise.** `rspack_javascript_tag "application"` with no build raises `RspackRails::Manifest::MissingEntry`, naming what to run, instead of linking a file that does not exist.
- **`RspackRails::Entrypoints.outputs`** is now `legacy_outputs` (what 1.x wrote to `app/assets/builds`).
- **Docker and Kamal.** Anything that served or copied `public/assets` for rspack's files looks at `public/rspack` now.

### From a version before 0.18.0

Upgrade to 0.19 first and fix what `rspack:doctor` reports there; 1.0 no longer knows the older files.

Before 0.13.0, `rspack.config.mjs` held the whole config. Run `bin/rails rspack:install` once and answer "y" to replace it (answer "d" first to see your own changes), then move those changes into the [`railsConfig` callback](configuration.md#customizing-the-rspack-config).

## Stability

From 1.0, rspack_rails follows [semantic versioning](https://semver.org) for the parts below. They change only in a major release, after at least one minor release that deprecates the old way with a warning.

- **Ruby API:** what [`sig/rspack_rails.rbs`](../sig/rspack_rails.rbs) lists: `RspackRails.config` and `configure`, `RspackRails.dev_server`, `DevServerProxy`, `RspackRails::Error`, and the view helpers `rspack_javascript_tag`, `rspack_stylesheet_tag` and `react_component`.
- **Rspack config:** `railsConfig` and the second argument of its callback ([Customizing the Rspack config](configuration.md#customizing-the-rspack-config)).
- **Rake tasks and environment variables:** the ones in the [Rake tasks](configuration.md#rake-tasks) and [Environment variables](configuration.md#environment-variables) tables, with what they do.
- **Build output** in `public/rspack`: fingerprinted files (`<name>-<hash>.js`, `.css` and assets), served under `/rspack/`, and that a build keeps the last `RSPACK_KEEP_BUILDS` builds' files and deletes the rest.
- **Supported versions:** Ruby, Rails and Node.js as in the [README's requirements](../README.md#requirements). Dropping one is a major release.

Everything else may change in any release: the installers and what they generate, `rspack:doctor`'s checks and wording, and `config/rspack/rails.mjs` beyond `railsConfig`. New features and new deprecations come in minor releases, fixes in patch releases.

CI runs real apps on Rails 7.2 with Sprockets and Rails 8.1 with Propshaft, and one with neither, against the oldest (2.0) and the latest Rspack 2.x.
