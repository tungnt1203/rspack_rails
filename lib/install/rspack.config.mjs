// The Rspack config of this Rails app, written by `bin/rails rspack:install`.
// It is yours: edit it freely. rspack_rails never rewrites it.
//
// What the Rails side needs from it:
//   - output in public/rspack with fingerprinted names (Rails serves it under /rspack/)
//   - .rspack-manifest.json there, which the view helpers read (the plugin at the bottom)
//   - the dev server on RSPACK_DEV_SERVER_HOST:RSPACK_DEV_SERVER_PORT, in memory,
//     reached through Rails under /rspack/ (RspackRails::DevServerProxy)
// Everything else is ordinary Rspack config: https://rspack.rs/config
//
// To add Sass, Tailwind CSS, React Fast Refresh and the like, see
// https://github.com/tungnt1203/rspack_rails/blob/main/docs/guide.md
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { defineConfig } from "@rspack/cli";

const root = import.meta.dirname;
// `rspack serve` and its aliases (`rspack dev`, `rspack server`, `rspack s`).
const isDevServer = process.argv.slice(2).some((arg) => ["serve", "dev", "server", "s"].includes(arg));
const isProduction = !isDevServer && (process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production");

// Keep these in sync with RspackRails.config (same env vars, same defaults).
const host = process.env.RSPACK_DEV_SERVER_HOST || "localhost";
const port = Number(process.env.RSPACK_DEV_SERVER_PORT || 3036);

// Browsers to compile for: your browserslist config when you have one,
// otherwise Baseline "widely available".
const hasBrowserslist = fs.existsSync(path.resolve(root, ".browserslistrc")) || "browserslist" in readJson("package.json");
const browsers = hasBrowserslist ? "browserslist" : "browserslist:baseline widely available";

// Entries: app/javascript/application.{js,ts,jsx,tsx} plus every file in
// app/javascript/entrypoints/, named after the file (admin.js -> "admin").
// Restart the dev server after adding an entrypoint.
const entry = entries();

export default defineConfig({
  context: root,
  mode: isProduction ? "production" : "development",
  target: ["web", browsers],
  // Production builds ship no source maps (they would be public in public/rspack).
  devtool: isProduction ? false : "cheap-module-source-map",
  // Reuse work across builds and dev server restarts (node_modules/.cache/rspack).
  cache: {
    type: "persistent",
    buildDependencies: [
      "rspack.config.mjs", "package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock",
      "bun.lockb", "tsconfig.json", ".browserslistrc",
    ]
      .map((file) => path.resolve(root, file))
      .filter((file) => fs.existsSync(file)),
    version: browsers,
    // `rspack serve` compiles with HMR, a build without: one cache per kind, or
    // the dev server would reuse a build's modules and fall back to full reloads.
    name: isDevServer ? "serve" : isProduction ? "production" : "development",
  },
  entry,
  // Under `rspack serve`, every entry on a page shares one runtime (runtime.js,
  // linked by the view helpers). Two runtimes on one page break HMR.
  optimization: { runtimeChunk: isDevServer ? { name: "runtime" } : false },
  // Rspack's size hints flag any entry over 244 KiB, which an app with React and
  // Turbo passes on day one. Set hints: "warning" to get them back.
  performance: { hints: false },
  output: {
    path: path.resolve(root, "public/rspack"),
    // Fingerprinted, so Rails can cache them for a year. Entries keep their names
    // under `rspack serve`, which has no cache to bust.
    filename: isDevServer ? "[name].js" : "[name]-[contenthash].js",
    chunkFilename: "[name]-[contenthash].js",
    cssFilename: isDevServer ? "[name].css" : "[name]-[contenthash].css",
    cssChunkFilename: "[name]-[contenthash].css",
    assetModuleFilename: "[name]-[contenthash][ext]",
    // Under `rspack serve`, Rails proxies /rspack/ to the dev server, so bundles,
    // chunks, workers and hot updates are same-origin with the page. Otherwise
    // "auto": chunks and images are found next to the script (any asset_host).
    publicPath: isDevServer ? "/rspack/" : "auto",
    // A build starts from an empty public/rspack (old chunks and a development
    // build's source maps must not ship), but not under `rspack serve`, which
    // keeps its files in memory. A build alongside the dev server (bin/rails test)
    // leaves the dev server's manifest alone.
    clean: !isDevServer && { keep: /\.rspack-dev-manifest\.json$/ },
  },
  resolve: {
    extensions: ["...", ".ts", ".jsx", ".tsx"],
    // Bare imports of app code: import "controllers/application", import "lib/utils".
    modules: ["node_modules", path.resolve(root, "app/javascript")],
    // "paths" aliases from tsconfig.json.
    tsConfig: fs.existsSync(path.resolve(root, "tsconfig.json")) ? path.resolve(root, "tsconfig.json") : undefined,
  },
  module: {
    rules: [
      {
        // TypeScript and JSX through Rspack's built-in SWC (no type checking).
        test: /\.(ts|jsx|tsx)$/,
        exclude: /node_modules/,
        loader: "builtin:swc-loader",
        options: {
          detectSyntax: "auto",
          jsc: { transform: { react: { runtime: "automatic", development: !isProduction } } },
        },
        type: "javascript/auto",
      },
      {
        // Images and fonts: inlined below 8 KB, emitted as files above.
        test: /\.(png|jpe?g|gif|svg|webp|avif|ico|woff2?|ttf|otf|eot)$/i,
        type: "asset",
      },
      {
        // Native CSS; *.module.css files become CSS modules.
        test: /\.css$/,
        type: "css/auto",
      },
    ],
  },
  // url("/icon.png") in CSS points at public/, served by Rails: keep it as written.
  // Rspack 2 would otherwise look for /icon.png at the root of the file system.
  externals: [
    ({ request, dependencyType }, callback) => {
      if (dependencyType === "url" && request.startsWith("/") && !request.startsWith("//")) {
        return callback(null, request, "asset");
      }
      callback();
    },
  ],
  // `rspack serve` compiles dynamic import()s on first use. The client posts to
  // /rspack/_rspack/lazy/trigger on the page's origin, which Rails proxies.
  lazyCompilation: isDevServer ? { imports: true, entries: false, serverUrl: "/rspack/" } : false,
  plugins: [imagesPlugin(), manifestPlugin()],
  // Tailwind watches the whole app for class names. Skip what Rails and rspack
  // write to, or every write triggers a rebuild.
  watchOptions: {
    ignored: ["node_modules", ".git", "log", "tmp", "storage", "public", "coverage"].map((dir) => `${root}/${dir}/**`),
  },
  devServer: {
    host,
    port,
    hot: true,
    // Everything stays in memory, served from the root (Rails strips /rspack/ when
    // it proxies), except the manifest the view helpers read.
    devMiddleware: { publicPath: "/", writeToDisk: (file) => path.basename(file) === ".rspack-dev-manifest.json" },
    // Rails serves public/. The dev server's own static directory (also public/)
    // would reload the page whenever a build writes there.
    static: false,
    // Editing a view reloads the page: views are rendered by Rails, so hot updates cannot change them.
    watchFiles: ["app/views", "app/helpers", "app/components"].map((dir) => path.resolve(root, dir)).filter((dir) => fs.existsSync(dir)),
    allowedHosts: "all",
    headers: { "Access-Control-Allow-Origin": "*" },
    client: { webSocketURL: webSocketURL(), overlay: true },
  },
});

function entries() {
  const found = {};
  for (const ext of ["js", "ts", "jsx", "tsx"]) {
    const file = `./app/javascript/application.${ext}`;
    if (!found.application && fs.existsSync(path.resolve(root, file))) found.application = file;
  }
  const dir = path.resolve(root, "app/javascript/entrypoints");
  if (fs.existsSync(dir)) {
    for (const file of fs.readdirSync(dir).sort()) {
      const match = file.match(/^(.+)\.(js|ts|jsx|tsx|css|scss|sass)$/);
      if (!match) continue;
      // admin.js and admin.css side by side make one entry with both.
      const files = [found[match[1]], `./app/javascript/entrypoints/${file}`].flat().filter(Boolean);
      found[match[1]] = files.length === 1 ? files[0] : files;
    }
  }
  return found;
}

// The HMR websocket is the one connection that skips Rails: the browser opens it to the
// dev server itself. Behind a forwarded port or a TLS proxy (Codespaces, a remote dev
// container), RSPACK_DEV_SERVER_PUBLIC_URL is the dev server's URL as the browser sees it,
// e.g. https://myapp-3036.app.github.dev.
function webSocketURL() {
  const value = process.env.RSPACK_DEV_SERVER_PUBLIC_URL;
  if (!value) return `ws://${host}:${port}/ws`;
  const url = new URL(value);
  url.protocol = { "http:": "ws:", "https:": "wss:" }[url.protocol] ?? url.protocol;
  if (url.pathname === "/") url.pathname = "/ws";
  return url.toString();
}

function readJson(file) {
  const full = path.resolve(root, file);
  return fs.existsSync(full) ? JSON.parse(fs.readFileSync(full, "utf8")) : {};
}

// ---- Rails: the files the view helpers link --------------------------------------------
// Everything below feeds RspackRails::Manifest. Leave it as it is unless you change
// where the build goes.

// Images for views: every file in app/javascript/images, as rspack_image_tag "logo.svg" and
// rspack_asset_path "icons/menu.svg" expect. Emitted as <name>-<hash>.<ext> and listed in the
// manifest under "assets" by its path in that directory. (Images that JavaScript or CSS imports
// do not need this.)
const images = {};
function imagesPlugin() {
  const name = "RspackRailsImages";
  const dir = path.resolve(root, "app/javascript/images");
  return {
    apply(compiler) {
      const { Compilation, sources } = compiler.rspack;
      compiler.hooks.thisCompilation.tap(name, (compilation) => {
        compilation.hooks.processAssets.tap({ name, stage: Compilation.PROCESS_ASSETS_STAGE_ADDITIONAL }, () => {
          for (const key of Object.keys(images)) delete images[key];
          if (!fs.existsSync(dir)) return;
          // A new file in the directory, or an edit, rebuilds.
          compilation.contextDependencies.add(dir);
          for (const item of fs.readdirSync(dir, { recursive: true, withFileTypes: true })) {
            if (!item.isFile() || item.name.startsWith(".")) continue;
            const file = path.join(item.parentPath, item.name);
            const relative = path.relative(dir, file).replaceAll("\\", "/");
            const content = fs.readFileSync(file);
            const hash = crypto.createHash("sha256").update(content).digest("hex").slice(0, 16);
            const { name: base, ext } = path.parse(relative);
            const output = `${path.posix.basename(base)}-${hash}${ext}`;
            compilation.fileDependencies.add(file);
            compilation.emitAsset(output, new sources.RawSource(content));
            images[relative] = output;
          }
        });
      });
    },
  };
}

// .rspack-manifest.json in public/rspack: for each entry, the scripts and stylesheets to
// link (runtime first), and the images above.
//   { "entries": { "print": { "js": [], "css": ["print-3f2a9c1d.css"], "stylesheetOnly": true } },
//     "assets": { "logo.svg": "logo-3f2a9c1d5e6f7a8b.svg" } }
// `rspack serve` writes .rspack-dev-manifest.json instead, which the helpers read while it runs:
// a build alongside it (bin/rails test) leaves it alone, so dev pages keep linking runtime.js.
function manifestPlugin() {
  const name = "RspackRailsManifest";
  const manifestName = isDevServer ? ".rspack-dev-manifest.json" : ".rspack-manifest.json";
  return {
    apply(compiler) {
      const { Compilation, sources } = compiler.rspack;
      compiler.hooks.thisCompilation.tap(name, (compilation) => {
        compilation.hooks.processAssets.tap({ name, stage: Compilation.PROCESS_ASSETS_STAGE_REPORT }, () => {
          const listed = {};
          // Files a script entry needs, such as a runtime chunk shared through
          // optimization.runtimeChunk: never deleted with a stylesheet-only entry's script.
          const needed = new Set();
          for (const [entryName, entrypoint] of compilation.entrypoints) {
            if (!stylesheetEntry(compiler, entryName)) entrypoint.getFiles().forEach((file) => needed.add(file));
          }
          for (const [entryName, entrypoint] of compilation.entrypoints) {
            const runtime = new Set(entrypoint.getRuntimeChunk()?.files ?? []);
            const files = entrypoint
              .getFiles()
              .filter((file) => !file.includes(".hot-update."))
              .sort((a, b) => runtime.has(b) - runtime.has(a));
            const stylesheetOnly = stylesheetEntry(compiler, entryName);
            let js = files.filter((file) => file.endsWith(".js"));
            // A stylesheet-only entry needs a script only under `rspack serve`, for
            // hot updates. Rspack 2.0 still emits an empty one in builds: drop it.
            if (stylesheetOnly && !isDevServer) {
              js.filter((file) => !needed.has(file)).forEach((file) => compilation.deleteAsset(file));
              js = [];
            }
            listed[entryName] = { js, css: files.filter((file) => file.endsWith(".css")), stylesheetOnly };
          }
          const manifest = { entries: listed, assets: images };
          compilation.emitAsset(manifestName, new sources.RawSource(`${JSON.stringify(manifest, null, 2)}\n`));
        });
      });
    },
  };
}

// Built from CSS alone (app/javascript/entrypoints/print.css).
function stylesheetEntry(compiler, entryName) {
  const imports = compiler.options.entry[entryName]?.import ?? [];
  return imports.length > 0 && imports.every((file) => /\.(css|scss|sass)$/.test(file));
}
