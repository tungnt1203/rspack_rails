import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@rspack/cli";

const root = path.dirname(fileURLToPath(import.meta.url));
const isDevServer = process.argv.includes("serve");
const isProduction =
  !isDevServer &&
  (process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production");

// React Fast Refresh under `rspack serve`, once rspack:install:react added the plugin.
const reactRefresh = isDevServer && hasPackage("@rspack/plugin-react-refresh");
const { ReactRefreshRspackPlugin } = reactRefresh ? await import("@rspack/plugin-react-refresh") : {};

// Bundle analysis (bin/rails rspack:analyze): a production build into
// tmp/rsdoctor, plus a single-file Rsdoctor report next to it.
const analyze = process.env.RSDOCTOR === "true";
const { RsdoctorRspackPlugin } = analyze ? await import("@rsdoctor/rspack-plugin") : {};
const analyzeDir = path.resolve(root, "tmp/rsdoctor");

// Keep these in sync with RspackRails.config (same env vars, same defaults).
const host = process.env.RSPACK_DEV_SERVER_HOST || "localhost";
const port = Number(process.env.RSPACK_DEV_SERVER_PORT || 3036);

// Entries: app/javascript/application.{js,ts,jsx,tsx} plus every file in
// app/javascript/entrypoints/, named after the file (admin.js -> "admin").
// Restart the dev server after adding an entrypoint.
const entry = {};
for (const ext of ["js", "ts", "jsx", "tsx"]) {
  const file = `./app/javascript/application.${ext}`;
  if (!entry.application && fs.existsSync(path.resolve(root, file))) entry.application = file;
}
const entrypointsDir = path.resolve(root, "app/javascript/entrypoints");
if (fs.existsSync(entrypointsDir)) {
  for (const file of fs.readdirSync(entrypointsDir).sort()) {
    const match = file.match(/^(.+)\.(js|ts|jsx|tsx)$/);
    if (match) entry[match[1]] = `./app/javascript/entrypoints/${file}`;
  }
}

function devtool() {
  const value = process.env.RSPACK_DEVTOOL;
  if (value === "false") return false;
  if (value) return value;
  return isProduction ? false : "cheap-module-source-map";
}

function hasPackage(name) {
  const file = path.resolve(root, "package.json");
  if (!fs.existsSync(file)) return false;
  const { dependencies = {}, devDependencies = {} } = JSON.parse(fs.readFileSync(file, "utf8"));
  return name in dependencies || name in devDependencies;
}

function lockfiles() {
  return ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock", "bun.lockb"]
    .map((file) => path.resolve(root, file))
    .filter((file) => fs.existsSync(file));
}

export default defineConfig({
  mode: isProduction ? "production" : "development",
  // Production builds ship no source maps (they would expose your source in
  // public/assets). Set RSPACK_DEVTOOL to override, e.g. "hidden-source-map"
  // for an error tracker, or "false" to turn them off in development too.
  devtool: devtool(),
  // Reuse work across builds and dev server restarts (node_modules/.cache/rspack).
  // Edits to this file or the lockfile start a fresh cache.
  cache: {
    type: "persistent",
    buildDependencies: [fileURLToPath(import.meta.url), ...lockfiles()],
  },
  entry,
  output: {
    path: analyze ? path.join(analyzeDir, "build") : path.resolve(root, "app/assets/builds"),
    filename: "[name].js",
    // ".digested" tells Propshaft the file is already fingerprinted.
    chunkFilename: "[name]-[contenthash].digested.js",
    // CSS imported from JavaScript. ".bundle" avoids clashing with
    // app/assets/stylesheets/application.css in Propshaft.
    cssFilename: "[name].bundle.css",
    cssChunkFilename: "[name]-[contenthash].digested.css",
    // Images and fonts imported from JS or CSS url(), also fingerprinted by rspack.
    assetModuleFilename: "[name]-[contenthash].digested[ext]",
    // Under `rspack serve`, chunks and hot updates load from the dev server.
    // Otherwise "auto": JS finds chunks and images next to its own script
    // (any assets prefix or asset_host), and CSS uses relative url()s that
    // Propshaft resolves and rewrites.
    publicPath: isDevServer ? `http://${host}:${port}/` : "auto",
  },
  resolve: {
    extensions: ["...", ".ts", ".jsx", ".tsx"],
    // Bare imports of app code work as they did with importmap
    // (import "controllers/application", import "lib/utils").
    modules: ["node_modules", path.resolve(root, "app/javascript")],
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
          jsc: {
            // Modern browsers, as Rails' allow_browser :modern expects.
            target: "es2022",
            transform: {
              react: { runtime: "automatic", development: !isProduction, refresh: reactRefresh },
            },
          },
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
        // Tailwind CSS v4 (bin/rails rspack:install:tailwind). Files without
        // Tailwind directives pass through untouched.
        use: hasPackage("@tailwindcss/webpack")
          ? [{ loader: "@tailwindcss/webpack", options: { base: root } }]
          : [],
      },
      // Sass (bin/rails rspack:install:sass); *.module.scss are CSS modules.
      // app/assets/stylesheets is a load path, as with dartsass-rails.
      ...(hasPackage("sass-loader")
        ? [
            {
              test: /\.s[ac]ss$/,
              type: "css/auto",
              loader: "sass-loader",
              options: { sassOptions: { loadPaths: [path.resolve(root, "app/assets/stylesheets")] } },
            },
          ]
        : []),
    ],
  },
  // `rspack serve` compiles dynamic import()s on first use. The page comes
  // from Rails, so the lazy compilation client must call the dev server, not
  // the page's origin. RSPACK_LAZY_COMPILATION=false compiles everything upfront.
  lazyCompilation:
    isDevServer && process.env.RSPACK_LAZY_COMPILATION !== "false"
      ? { imports: true, entries: false, serverUrl: `http://${host}:${port}/` }
      : false,
  plugins: [
    reactRefresh && new ReactRefreshRspackPlugin(),
    analyze &&
      new RsdoctorRspackPlugin({
        disableClientServer: true,
        // controllers/autoload and components/mount are side-effect imports by design.
        linter: { rules: { "tree-shaking-side-effects-only": "off" } },
        output: { mode: "brief", reportDir: analyzeDir, options: { type: ["html"] } },
      }),
  ].filter(Boolean),
  // Tailwind watches the whole app for class names. Skip directories that
  // Rails and rspack itself write to, or every write triggers a rebuild.
  watchOptions: {
    ignored: ["node_modules", ".git", "log", "tmp", "storage", "public", "coverage", "app/assets/builds"]
      .map((dir) => `${root.replaceAll("\\", "/")}/${dir}/**`),
  },
  devServer: {
    host,
    port,
    hot: true,
    // Keep app/assets/builds current while the dev server runs, so Propshaft
    // (and `stylesheet_link_tag :app`) never serve a stale bundle. Hot update
    // files stay in memory so they never reach public/assets.
    devMiddleware: { writeToDisk: (file) => !/\.hot-update\./.test(file) },
    allowedHosts: "all",
    headers: { "Access-Control-Allow-Origin": "*" },
    client: {
      webSocketURL: `ws://${host}:${port}/ws`,
      overlay: true,
    },
  },
});
