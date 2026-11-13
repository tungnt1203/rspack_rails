// Types for files rspack bundles that TypeScript cannot read itself.
// Stylesheets: `import "./application.css"` and CSS modules.
declare module "*.css";
declare module "*.scss";
declare module "*.sass";

// Images and fonts: the default export is the file's URL.
declare module "*.png" { const url: string; export default url; }
declare module "*.jpg" { const url: string; export default url; }
declare module "*.jpeg" { const url: string; export default url; }
declare module "*.gif" { const url: string; export default url; }
declare module "*.svg" { const url: string; export default url; }
declare module "*.webp" { const url: string; export default url; }
declare module "*.avif" { const url: string; export default url; }
declare module "*.ico" { const url: string; export default url; }
declare module "*.woff" { const url: string; export default url; }
declare module "*.woff2" { const url: string; export default url; }
declare module "*.ttf" { const url: string; export default url; }
declare module "*.otf" { const url: string; export default url; }
declare module "*.eot" { const url: string; export default url; }
