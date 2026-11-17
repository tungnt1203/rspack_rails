// Registers every app/javascript/controllers/**/*_controller.{js,ts} with Stimulus.
// Managed by rspack_rails: new controllers need no manual import, and edited
// controllers are hot-swapped under `rspack serve` without a page reload.
import { application } from "./application"

const controllers = () =>
  import.meta.webpackContext("./", { recursive: true, regExp: /_controller\.[jt]s$/ })

// "./users/profile_controller.js" -> "users--profile"
const identifierFor = (key) =>
  key
    .replace(/^\.\//, "")
    .replace(/_controller\.[jt]s$/, "")
    .replace(/\//g, "--")
    .replace(/_/g, "-")

const registerAll = (context) => {
  context.keys().forEach((key) => {
    const controller = context(key).default
    if (controller) application.register(identifierFor(key), controller)
  })
}

const context = controllers()
registerAll(context)

if (import.meta.webpackHot) {
  // Stimulus unloads an identifier before registering it again, so
  // re-registering swaps connected controllers in place.
  import.meta.webpackHot.accept(context.id, () => registerAll(controllers()))
}
