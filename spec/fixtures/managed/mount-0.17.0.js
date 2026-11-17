// Mounts React components into elements rendered by `react_component`:
//   <%= react_component "Hello", name: "World" %>
//   -> <div data-react-component="Hello" data-react-props='{"name":"World"}'>
// Managed by rspack_rails: every app/javascript/components/**/*.{jsx,tsx} is
// available by its path ("admin/Chart" for components/admin/Chart.jsx). Works
// with Turbo Drive, frames and streams: elements are mounted when they enter
// the page and unmounted when they leave it.
import { createElement } from "react"
import { createRoot } from "react-dom/client"

const components = () =>
  import.meta.webpackContext("./", { recursive: true, regExp: /\.[jt]sx$/ })

const nameFor = (key) => key.replace(/^\.\//, "").replace(/\.[jt]sx$/, "")

let registry = {}
const load = (context) => {
  registry = {}
  context.keys().forEach((key) => {
    const component = context(key).default
    if (component) registry[nameFor(key)] = component
  })
}

const roots = new Map()
const SELECTOR = "[data-react-component]"

const render = (element) => {
  const name = element.dataset.reactComponent
  const component = registry[name]
  if (!component) {
    console.error(`[rspack_rails] No component "${name}" in app/javascript/components`)
    return
  }
  const props = JSON.parse(element.dataset.reactProps || "{}")
  let root = roots.get(element)
  if (!root) {
    root = createRoot(element)
    roots.set(element, root)
  }
  root.render(createElement(component, props))
}

const mountWithin = (node) => {
  if (node.nodeType !== Node.ELEMENT_NODE) return
  if (node.matches(SELECTOR)) render(node)
  node.querySelectorAll(SELECTOR).forEach((element) => roots.has(element) || render(element))
}

const unmountDetached = () => {
  roots.forEach((root, element) => {
    if (element.isConnected) return
    root.unmount()
    roots.delete(element)
  })
}

const context = components()
load(context)

const start = () => {
  mountWithin(document.documentElement)
  new MutationObserver((mutations) => {
    for (const { addedNodes } of mutations) addedNodes.forEach(mountWithin)
    unmountDetached()
  }).observe(document.documentElement, { childList: true, subtree: true })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true })
} else {
  start()
}

if (import.meta.webpackHot) {
  import.meta.webpackHot.accept(context.id, () => {
    const previous = registry
    load(components())
    // React Fast Refresh updates edited components in place and keeps their
    // state; rendering them again here would remount them. Re-render only
    // when Fast Refresh is off or the component is new.
    const fastRefresh = Boolean(window.__reactRefreshInjected)
    document.querySelectorAll(SELECTOR).forEach((element) => {
      const name = element.dataset.reactComponent
      if (!fastRefresh || !roots.has(element) || !(name in previous)) render(element)
    })
  })
}
