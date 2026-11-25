# Upgrading

[Back to the README](../README.md)

## Updating the gem

```bash
bundle update rspack_rails
bin/rails rspack:doctor
```

`rspack.config.mjs` is yours and the gem never touches it, so an update changes only the Ruby side: helpers, the dev server proxy, the rake tasks and the doctor. When a release changes what the config must provide (the manifest format, say), the [CHANGELOG](../CHANGELOG.md) says what to copy from `lib/install/rspack.config.mjs` in the gem, and `rspack:doctor` reports a config that no longer fits.

Some releases also change other files (`Dockerfile`, `bin/setup`). The CHANGELOG says when to run `bin/rails rspack:install` again. Running it again is safe: it leaves your entry, layouts and `Procfile.dev` alone when they are already set up, and asks before it replaces a different `rspack.config.mjs`.

## Stability

From 1.0, rspack_rails follows [semantic versioning](https://semver.org) for the parts below. They change only in a major release, after at least one minor release that deprecates the old way with a warning.

- **Ruby API:** what [`sig/rspack_rails.rbs`](../sig/rspack_rails.rbs) lists: `RspackRails.config` and `configure`, `RspackRails.dev_server`, `DevServerProxy`, `RspackRails::Error`, and the view helpers `rspack_javascript_tag`, `rspack_stylesheet_tag`, `rspack_image_tag` and `rspack_asset_path`.
- **The manifest** the config writes to `public/rspack/.rspack-manifest.json` (`entries` and `assets`), which the view helpers read.
- **Rake tasks and environment variables:** the ones in the [Rake tasks](configuration.md#rake-tasks) and [Environment variables](configuration.md#environment-variables) tables, with what they do.
- **Build output** in `public/rspack`: fingerprinted files (`<name>-<hash>.js`, `.css` and assets), served under `/rspack/`, and that a build starts from an empty directory.
- **Supported versions:** Ruby, Rails and Node.js as in the [README's requirements](../README.md#requirements). Dropping one is a major release.

Everything else may change in any release: the installers and what they generate, `rspack:doctor`'s checks and wording, and the config `rspack:install` generates. New features and new deprecations come in minor releases, fixes in patch releases.

CI runs real apps on Rails 7.2 with Sprockets and Rails 8.1 with Propshaft, and one with neither, against the oldest (2.0) and the latest Rspack 2.x.
