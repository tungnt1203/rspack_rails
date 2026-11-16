// Rspack config. The defaults for this Rails app live in config/rspack/rails.mjs,
// which rspack_rails keeps up to date when you upgrade the gem. Change them here.
import { railsConfig } from "./config/rspack/rails.mjs";

export default railsConfig((config, { isDevServer, isProduction }) => {
  // config.resolve.alias = { "@": `${config.context}/app/javascript` };
  // config.plugins.push(new SomeRspackPlugin());
  return config;
});
