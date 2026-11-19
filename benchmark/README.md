# Build benchmark

Rspack, esbuild and webpack building the same generated React + TypeScript app: the numbers behind [Rails + Rspack: esbuild speed, webpack features, one command](https://dev.to/tungnt1203/rails-rspack-esbuild-speed-webpack-features-one-command-4652).

```bash
cd benchmark
npm install
ruby run.rb 1000   # or 5000
```

`run.rb` generates `src/` (N components in a tree, each using React state, lodash-es and date-fns), then prints a table:

- **production build** and **development build**: the median of 5 cold builds, after one warm-up run.
- **rebuild after editing one component**: each tool in watch mode; the median of 10 edits to a leaf component, timed until the bundle on disk contains the edit.

All three build to ES2022 with source maps. esbuild runs with the flags jsbundling-rails uses, plus `--minify` for production. webpack uses swc-loader. Times include `npx` and Node startup, about 0.2 s. This is a bundler comparison: `rspack.config.mjs` here is a minimal config, not the gem's `config/rspack/rails.mjs`.

## Results

Apple M1 (8 cores), Node 26.5.1, November 2026, with the package versions pinned in `package.json`.

| 1,000 components | production build | development build | rebuild after editing one component |
|---|---|---|---|
| rspack | 0.73 s | 0.55 s | 83 ms |
| esbuild | 0.51 s | 0.54 s | 279 ms |
| webpack | 4.10 s | 1.46 s | 288 ms |

| 5,000 components | production build | development build | rebuild after editing one component |
|---|---|---|---|
| rspack | 1.59 s | 0.99 s | 495 ms |
| esbuild | 1.05 s | 0.92 s | 948 ms |
| webpack | 14.58 s | 3.39 s | 1,298 ms |

Gzipped production output for 1,000 components: rspack 100.5 KB, webpack 100.3 KB, esbuild 120.1 KB.

Runs vary by 10 to 30% from one to the next, more for webpack. The ordering has held in every run so far: esbuild fastest on cold builds, Rspack fastest on rebuilds, webpack slowest on both.

Remember that esbuild has no hot module replacement. After its rebuild the browser still reloads the whole page, while Rspack swaps the changed module in place.
