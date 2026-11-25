// Registers every Stimulus controller under app/javascript/controllers:
// hello_controller.js -> "hello", admin/user_controller.js -> "admin--user".
// New controllers need no manual import, and under `rspack serve` an edited or
// added controller is swapped in the open page without a reload.
import { application } from "./application"

const controllers = () => import.meta.webpackContext(".", { recursive: true, regExp: /_controller\.[jt]s$/ })

// "./admin/user_controller.js" -> "admin--user"
const identifierFor = (key) =>
  key
    .replace(/^\.\//, "")
    .replace(/_controller\.[jt]s$/, "")
    .replaceAll("/", "--")
    .replaceAll("_", "-")

const registerAll = (context) => {
  for (const key of context.keys()) {
    const controller = context(key).default
    if (controller) application.register(identifierFor(key), controller)
  }
}

const context = controllers()
registerAll(context)

// Stimulus unloads an identifier before registering it again, so registering
// again swaps connected controllers in place.
if (import.meta.webpackHot) {
  import.meta.webpackHot.accept(context.id, () => registerAll(controllers()))
}
