import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@rspack/cli";

const root = path.dirname(fileURLToPath(import.meta.url));
const isProduction =
  process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production";

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
    publicPath: "/assets/",
  },
});
