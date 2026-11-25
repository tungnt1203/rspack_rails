// Registers every Stimulus controller under app/javascript/controllers:
// hello_controller.js -> "hello", admin/user_controller.js -> "admin--user".
import { application } from "./application"

const controllers = import.meta.webpackContext(".", { recursive: true, regExp: /_controller\.[jt]s$/ })

for (const key of controllers.keys()) {
  const name = key
    .replace(/^\.\//, "")
    .replace(/_controller\.[jt]s$/, "")
    .replaceAll("/", "--")
    .replaceAll("_", "-")
  application.register(name, controllers(key).default)
}
