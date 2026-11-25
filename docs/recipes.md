# Recipes

`rspack.config.mjs` is an ordinary Rspack config, so anything [rspack.rs](https://rspack.rs) documents works in it. These are the changes Rails apps ask for most, written against the file `rspack:install` generates. [Usage](guide.md#adding-tools) has TypeScript, Stimulus, Sass, Tailwind CSS and React.

Built-in plugins come from `@rspack/core`, which `rspack:install` already added:

```js
// rspack.config.mjs
import { rspack } from "@rspack/core";
```

Each recipe says where its lines go: `plugins`, `module.rules` or `resolve`. After editing the config, restart `bin/dev`.

## Values from the environment

`DefinePlugin` replaces an identifier with a value when the code is built. Use it for settings that differ between development and production, and for anything the page should know at build time. The value is pasted as code, so strings need `JSON.stringify`.

```js
// in plugins
new rspack.DefinePlugin({
  __DEV__: JSON.stringify(!isProduction),
  "process.env.API_URL": JSON.stringify(process.env.API_URL ?? "/api"),
}),
```

```js
if (__DEV__) console.log("debug")
fetch(process.env.API_URL + "/posts")
```

Only what you list is defined, so a secret in the shell never ends up in a public file by accident. `EnvironmentPlugin` is the short form for variables with the same name: `new rspack.EnvironmentPlugin({ API_URL: "/api" })` defines `process.env.API_URL`, with `/api` when the variable is unset.

Anything in `public/rspack` is public. Put in the bundle only what a visitor may read.

## Short import paths

`app/javascript` is already on the module path, so `import "lib/utils"` works. For named prefixes, add an alias:

```js
// in resolve
alias: {
  "@": path.resolve(root, "app/javascript"),
  "@components": path.resolve(root, "app/javascript/components"),
},
```

With a `tsconfig.json`, `paths` in it are honored instead and the alias is not needed.

## Copy files to the build

`CopyRspackPlugin` copies files into `public/rspack` unchanged. It fits files that must exist next to the bundle, such as a service worker or a WebAssembly file that is loaded by name. For images that views show, use `app/javascript/images` and `rspack_image_tag`: they are fingerprinted and listed in the manifest. Files copied this way are neither.

```js
// in plugins
new rspack.CopyRspackPlugin({
  patterns: [{ from: "app/javascript/static" }], // app/javascript/static/sw.js -> public/rspack/sw.js
}),
```

The plugin raises an error when the directory is empty or missing, so create it first.

## Less and PostCSS

Rspack handles CSS itself. A preprocessor is one more rule, like Sass in the guide:

```bash
npm install --save-dev less less-loader
```

```js
// in module.rules
{ test: /\.less$/, type: "css/auto", loader: "less-loader" },
```

PostCSS plugins, such as autoprefixer or nesting, run through `postcss-loader`:

```bash
npm install --save-dev postcss postcss-loader postcss-preset-env
```

```js
// in module.rules, on the CSS rule
{
  test: /\.css$/,
  type: "css/auto",
  use: [{ loader: "postcss-loader", options: { postcssOptions: { plugins: ["postcss-preset-env"] } } }],
},
```

Tailwind CSS has its own loader and takes the place of `postcss-loader` on that rule: see the guide.

## Vue

```bash
npm install vue
npm install --save-dev rspack-vue-loader
```

```js
import { VueLoaderPlugin } from "rspack-vue-loader";

// in module.rules
{
  test: /\.vue$/,
  loader: "rspack-vue-loader",
  options: { experimentalInlineMatchResource: true },
},

// in resolve.extensions, add ".vue"

// in plugins
new VueLoaderPlugin(),
new rspack.DefinePlugin({
  __VUE_OPTIONS_API__: true,
  __VUE_PROD_DEVTOOLS__: false,
  __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
}),
```

The three `DefinePlugin` flags are the ones Vue asks a bundler to set (without them its console warns in development). `<script lang="ts">` works as it is, and so do `<style>` blocks. Edited components are swapped in place under `rspack serve`. Mount the app from your entry:

```js
// app/javascript/application.js
import { createApp } from "vue"
import App from "./App.vue"

createApp(App).mount("#app")
```

[rspack.rs/guide/integrations/vue](https://rspack.rs/guide/integrations/vue) covers Vue 2, JSX and the devtools.

## Svelte

```bash
npm install svelte
npm install --save-dev svelte-loader
```

```js
// in module.rules
{
  test: /\.svelte$/,
  loader: "svelte-loader",
  options: {
    compilerOptions: { dev: !isProduction },
    emitCss: isProduction,
  },
},

// in resolve
extensions: ["...", ".svelte"],
mainFields: ["svelte", "browser", "module", "main"],
```

Under `rspack serve`, an edited `.svelte` file reloads the page instead of being swapped in place (checked with Svelte 5).

## Preact

Preact reads the same JSX as React. Point the JSX transform at it and alias `react`, so libraries written for React keep working:

```bash
npm install preact
```

```js
// in the swc-loader rule: jsc.transform.react
react: { runtime: "automatic", importSource: "preact", development: !isProduction },

// in resolve
alias: { react: "preact/compat", "react-dom": "preact/compat" },
```

Hot updates for Preact components need `@rspack/plugin-preact-refresh` and a loader: [rspack.rs/guide/integrations/preact](https://rspack.rs/guide/integrations/preact) has both.

## Old libraries that expect globals

A library that reads `window.$` or `jQuery` without importing it can have them provided:

```bash
npm install jquery
```

```js
// in plugins
new rspack.ProvidePlugin({ $: "jquery", jQuery: "jquery" }),
```

Any module that uses `$` as a free variable now gets jQuery, without an import. Code of your own should import it.

## Split code

Two ways to keep what a page downloads small.

**Load on demand.** A dynamic `import()` becomes a chunk of its own, fetched when the code reaches it. Use it for what few visitors need: a chart library, an editor, an admin-only screen.

```js
document.querySelector("#chart-button").addEventListener("click", async () => {
  const { renderChart } = await import("./chart")
  renderChart()
})
```

The chunk is written to `public/rspack` as `<name>-<hash>.js` and loaded from next to the entry, so it needs nothing in the view and works behind an `asset_host`. To fetch it while the browser is idle, before anyone clicks, add a magic comment: `import(/* webpackPrefetch: true */ "./chart")`. Use `webpackPreload: true` for a chunk the page needs right away.

**Share code between entries.** Pages with two entries load a module both import (Turbo, your Stimulus `application`, a UI library) twice, once per entry. Put it in a chunk of its own:

```js
// rspack.config.mjs
optimization: {
  runtimeChunk: { name: "runtime" },
  splitChunks: { chunks: "all" },
},
```

The shared chunk is listed in the manifest next to the entries that use it, so `rspack_javascript_tag` links it and the runtime before the entry. Keep the runtime chunk shared, as in [Entry points](guide.md#entry-points): without it each entry runs its own copy of the shared modules, which defeats the split. Rspack decides what is worth a chunk (it skips small modules), so check the result with `bin/rails rspack:build` before you rely on it.

## Lightning CSS instead of PostCSS

Rspack's built-in Lightning CSS loader adds vendor prefixes and compiles newer CSS syntax (nesting, `color-mix()`, `light-dark()`) for your browsers, with no `postcss.config.js` and no extra packages. Use it when you did not need PostCSS plugins other than Autoprefixer:

```js
// the css rule in module.rules
{
  test: /\.css$/,
  use: [{ loader: "builtin:lightningcss-loader" }],
  type: "css/auto",
},
```

It reads the same targets as the rest of the build (your `.browserslistrc`, or Baseline widely available), so `user-select: none` comes out with its `-webkit-` prefix where an old Safari needs it. Tailwind CSS and Sass keep their own steps; see [Usage](guide.md#adding-tools). With a `postcss.config.js` for other plugins, stay on the [PostCSS recipe](#less-and-postcss).

## Where images and fonts are inlined

The `asset` rule in `rspack.config.mjs` inlines a file under 8 KB into the bundle as a data URI and emits a larger one. Each inlined file saves a request and adds its weight to every page that loads the bundle. Change the limit on the rule:

```js
{
  test: /\.(png|jpe?g|gif|svg|webp|avif|ico|woff2?|ttf|otf|eot)$/i,
  type: "asset",
  parser: { dataUrlCondition: { maxSize: 2 * 1024 } },
},
```

Use `type: "asset/resource"` to never inline (fonts are usually better as files, which the browser caches on their own).

## Leave out what you do not use

`IgnorePlugin` skips modules that a library pulls in by a dynamic path. The usual case is Moment.js, which bundles every locale:

```js
// in plugins
new rspack.IgnorePlugin({ resourceRegExp: /^\.\/locale$/, contextRegExp: /moment$/ }),
```

Import the locales you want by name. The ignored ones throw if the code ever reaches them, so use this when you know it does not.

## Sizes, duplicates and slow builds

- **Bundle contents and duplicates:** Rsdoctor, in [Production](production.md#bundle-analysis).
- **What a build spends its time on:** Rsdoctor's timeline, or [rspack.rs/guide/diagnostics/profile](https://rspack.rs/guide/diagnostics/profile).
- **Circular imports:** `new rspack.CircularCheckRspackPlugin({ exclude: /node_modules/ })` in `plugins` lists the ones in your code as warnings. Add `failOnError: true` to fail the build; without the `exclude`, cycles inside packages such as Svelte would fail it too.

## Anything else

Rspack accepts most webpack loaders and many webpack plugins. [Community plugin compatibility](https://rspack.rs/plugins/community-plugin-compatibility) lists which. If a plugin wants HTML output, skip it: Rails renders the HTML, and `rspack_javascript_tag` and `rspack_stylesheet_tag` link the build.
