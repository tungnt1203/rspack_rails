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

export default defineConfig({
  mode: isProduction ? "production" : "development",
  devtool: "source-map",
  entry: {
    application: "./app/javascript/application.js",
  },
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
    // (and `stylesheet_link_tag :app`) never serve a stale bundle.
    devMiddleware: { writeToDisk: true },
    allowedHosts: "all",
    headers: { "Access-Control-Allow-Origin": "*" },
    client: {
      webSocketURL: `ws://${host}:${port}/ws`,
      overlay: true,
    },
  },
});
