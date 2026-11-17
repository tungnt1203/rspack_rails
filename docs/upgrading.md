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

### From a version before 0.18.0

Upgrade to 0.19 first and fix what `rspack:doctor` reports there; 1.0 no longer knows the older files.

Before 0.13.0, `rspack.config.mjs` held the whole config. Run `bin/rails rspack:install` once and answer "y" to replace it (answer "d" first to see your own changes), then move those changes into the [`railsConfig` callback](configuration.md#customizing-the-rspack-config).

## Stability

From 1.0, rspack_rails follows [semantic versioning](https://semver.org) for the parts below. They change only in a major release, after at least one minor release that deprecates the old way with a warning.

- **Ruby API:** what [`sig/rspack_rails.rbs`](../sig/rspack_rails.rbs) lists: `RspackRails.config` and `configure`, `RspackRails.dev_server`, `DevServerProxy`, `RspackRails::Error`, and the view helpers `rspack_javascript_tag`, `rspack_stylesheet_tag` and `react_component`.
- **Rspack config:** `railsConfig` and the second argument of its callback ([Customizing the Rspack config](configuration.md#customizing-the-rspack-config)).
- **Rake tasks and environment variables:** the ones in the [Rake tasks](configuration.md#rake-tasks) and [Environment variables](configuration.md#environment-variables) tables, with what they do.
- **Build output names** in `app/assets/builds`: `<entry>.js`, `<entry>.bundle.css` and the fingerprinted `*.digested.*`, and that a build deletes only Rspack's own files there.
- **Supported versions:** Ruby, Rails and Node.js as in the [README's requirements](../README.md#requirements). Dropping one is a major release.

Everything else may change in any release: the installers and what they generate, `rspack:doctor`'s checks and wording, and `config/rspack/rails.mjs` beyond `railsConfig`. New features and new deprecations come in minor releases, fixes in patch releases.

CI runs real apps on Rails 7.2 with Sprockets and Rails 8.1 with Propshaft, against the oldest (2.0) and the latest Rspack 2.x.
