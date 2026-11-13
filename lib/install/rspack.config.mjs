import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@rspack/cli";

const root = path.dirname(fileURLToPath(import.meta.url));
const isDevServer = process.argv.includes("serve");
const isProduction =
  !isDevServer &&
  (process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production");

// Keep these in sync with RspackRails.config (same env vars, same defaults).
const host = process.env.RSPACK_DEV_SERVER_HOST || "localhost";
const port = Number(process.env.RSPACK_DEV_SERVER_PORT || 3036);

// Entries: app/javascript/application.{js,ts} plus every file in
// app/javascript/entrypoints/, named after the file (admin.js -> "admin").
// Restart the dev server after adding an entrypoint.
const entry = {};
for (const ext of ["js", "ts"]) {
  const file = `./app/javascript/application.${ext}`;
  if (!entry.application && fs.existsSync(path.resolve(root, file))) entry.application = file;
}
const entrypointsDir = path.resolve(root, "app/javascript/entrypoints");
if (fs.existsSync(entrypointsDir)) {
  for (const file of fs.readdirSync(entrypointsDir).sort()) {
    const match = file.match(/^(.+)\.(js|ts)$/);
    if (match) entry[match[1]] = `./app/javascript/entrypoints/${file}`;
  }
}

export default defineConfig({
  mode: isProduction ? "production" : "development",
  devtool: "source-map",
  entry,
  output: {
    path: path.resolve(root, "app/assets/builds"),
    filename: "[name].js",
    // ".digested" tells Propshaft the file is already fingerprinted.
    chunkFilename: "[name]-[contenthash].digested.js",
    // CSS imported from JavaScript. ".bundle" avoids clashing with
    // app/assets/stylesheets/application.css in Propshaft.
    cssFilename: "[name].bundle.css",
    cssChunkFilename: "[name]-[contenthash].digested.css",
    // Under `rspack serve`, chunks and hot updates load from the dev server.
    publicPath: isDevServer ? `http://${host}:${port}/` : "/assets/",
  },
  resolve: {
    extensions: ["...", ".ts"],
    // Bare imports of app code work as they did with importmap
    // (import "controllers/application", import "lib/utils").
    modules: ["node_modules", path.resolve(root, "app/javascript")],
  },
  module: {
    rules: [
      {
        // Transpile TypeScript with Rspack's built-in SWC (no type checking).
        test: /\.ts$/,
        exclude: /node_modules/,
        loader: "builtin:swc-loader",
        options: { jsc: { parser: { syntax: "typescript" } } },
        type: "javascript/auto",
      },
      {
        // Native CSS; *.module.css files become CSS modules.
        test: /\.css$/,
        type: "css/auto",
      },
    ],
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
