// Drives a real browser against `rspack serve` + `rails server` and checks
// that edits are applied as hot updates, without a page reload.
// Run by bin/integration-hmr:   node hmr_check.mjs <app dir> <url>
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const [appDir, url = "http://localhost:3000/"] = process.argv.slice(2);
// playwright is installed in the generated app, not next to this file.
const { chromium } = createRequire(path.join(appDir, "package.json"))("playwright");

const file = (relative) => path.join(appDir, relative);
const edit = (relative, change) => fs.writeFileSync(file(relative), change(fs.readFileSync(file(relative), "utf8")));

let failures = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log(`✓ ${name}`);
  } catch (error) {
    failures++;
    console.log(`✗ ${name}\n    ${error.message.split("\n")[0]}`);
  }
}

const browser = await chromium.launch();
const page = await browser.newPage();
const logs = [];
page.on("console", (message) => logs.push(`${message.type()}: ${message.text()}`));
page.on("pageerror", (error) => logs.push(`pageerror: ${error.message}`));

await page.goto(url);
await page.waitForFunction(() => document.querySelector("#count")?.textContent === "0 clicks");
// Survives hot updates; gone after a reload.
await page.evaluate(() => (window.__noReload = true));
const notReloaded = async () => {
  if (!(await page.evaluate(() => window.__noReload === true))) throw new Error("the page reloaded");
};
const waitFor = (fn, arg) => page.waitForFunction(fn, arg, { timeout: 20_000 });

await check("Stimulus controller edit is hot-swapped and keeps its state", async () => {
  for (let i = 0; i < 3; i++) await page.click("#increment");
  await waitFor(() => document.querySelector("#count").textContent === "3 clicks");
  edit("app/javascript/controllers/counter_controller.js", (source) => source.replace('"click"', '"tap"'));
  await waitFor(() => document.querySelector("#count").textContent === "3 taps");
  await notReloaded();
});

await check("A new controller file connects without a reload", async () => {
  fs.writeFileSync(
    file("app/javascript/controllers/greeting_controller.js"),
    `import { Controller } from "@hotwired/stimulus"\n\n` +
      `export default class extends Controller {\n  connect() {\n    this.element.textContent = "connected"\n  }\n}\n`,
  );
  await waitFor(() => document.querySelector("#greeting").textContent === "connected");
  await notReloaded();
});

await check("CSS edit applies without a reload", async () => {
  edit("app/javascript/application.css", (source) => `${source}\n.probe { outline-color: rgb(1, 2, 3); }\n`);
  await waitFor(() => getComputedStyle(document.querySelector(".probe")).outlineColor === "rgb(1, 2, 3)");
  await notReloaded();
});

await check("Editing a view reloads the page, with the view's new Tailwind class", async () => {
  // Views are rendered by Rails: rspack serve reloads the page (watchFiles),
  // and Tailwind has generated the class by then.
  edit("app/views/pages/home.html.erb", (source) => `${source}\n<p id="new-view" class="text-fuchsia-900">new</p>\n`);
  await page.waitForSelector("#new-view", { timeout: 20_000 });
  if (await page.evaluate(() => window.__noReload === true)) throw new Error("the page did not reload");
  await waitFor(() => {
    const color = (selector) => getComputedStyle(document.querySelector(selector)).color;
    return color("#new-view") !== color(".probe");
  });
});

await browser.close();

if (failures > 0) {
  console.log("\nBrowser console:");
  for (const line of logs.slice(-30)) console.log(`  ${line}`);
  process.exit(1);
}
