const production = process.env.NODE_ENV === "production";
export default {
  mode: production ? "production" : "development",
  entry: { application: "./src/application.tsx" },
  output: { path: new URL("./out/webpack", import.meta.url).pathname, clean: true },
  devtool: "source-map",
  target: ["web", "es2022"],
  resolve: { extensions: [".tsx", ".ts", ".js"] },
  module: {
    rules: [{
      test: /\.tsx?$/,
      loader: "swc-loader",
      options: { jsc: { target: "es2022", parser: { syntax: "typescript", tsx: true }, transform: { react: { runtime: "automatic", development: !production } } } },
    }],
  },
};
