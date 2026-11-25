# Troubleshooting

[Back to the README](../README.md)

Start with `bin/rails rspack:doctor`. It covers the usual setup mistakes and says what to fix.

## `export 'foo' (imported as 'foo') was not found` fails the build

Since Rspack 2, importing a name that a module does not export is an error, not a warning. It often shows up after migrating from importmap, where the browser only failed when the code ran.

Fix the import, or turn it back into a warning in `rspack.config.mjs`:

```js
module: { parser: { javascript: { exportsPresence: "warn" } }, rules: [/* ... */] },
```

## Pages load old code after I stop the dev server

`public/rspack` holds the last `bin/rails rspack:build`, which is what pages link while the dev server is stopped. Run `bin/rails rspack:build` to refresh it. It also runs before tests and `assets:precompile`.

## `rspack has no entry named "application"`

No build lists that entry yet. Start the dev server with `bin/dev`, or run `bin/rails rspack:build`. For a new file in `app/javascript/entrypoints/`, restart the dev server. The message names the entries the manifest has.

## `image_tag` cannot find an image

Without Propshaft or Sprockets, `image_tag "logo.png"` has nothing to look it up in. Put the image in `app/javascript/images/` and use `rspack_image_tag "logo.png"` (or `rspack_asset_path "logo.png"` for the URL). Rspack fingerprints it. Or put it in `public/` and use `image_tag "/logo.png"`.

## The page has no styles

When the application entry imports CSS, Rspack writes it to its own file, and the layout has to link it. Add `<%= rspack_stylesheet_tag "application" %>` to the layout's `<head>`. `rspack:doctor` says "the application entry builds CSS that no layout links" when it is missing.

## JavaScript loads twice, or the dev server never starts

- A layout that still has `javascript_importmap_tags` next to `rspack_javascript_tag` loads both. Remove the importmap tag once Rspack replaces it.
- `bin/dev` has to start `Procfile.dev` (which runs `bin/rails server` and the dev server) and be executable. Running `bin/rails server` alone gives you the last build, with no hot updates. Run `bin/rails rspack:install` to restore the script, or `chmod +x bin/dev`.

## The Docker build fails at `npm ci`

A frozen install needs the lockfile in the image. Commit `package-lock.json` (or `yarn.lock`, `pnpm-lock.yaml`, `bun.lock`) and make sure `.dockerignore` does not list it. `rspack:doctor` warns when the lockfile is missing from an app that has a `Dockerfile`. See [Deploying](production.md#deploying-docker-and-kamal) for the rest of the Docker setup.

## `assets:precompile` fails because Node.js is missing

The build stage of the `Dockerfile` needs Node.js and the node modules, which Rails does not add for apps created without a JavaScript bundler. Re-run `bin/rails rspack:install` to add them, or see [Deploying](production.md#deploying-docker-and-kamal).

## Something else

[Open an issue](https://github.com/tungnt1203/rspack_rails/issues/new) with the output of `bin/rails rspack:doctor`, your Rails and Node.js versions, and the steps that reproduce the problem.
