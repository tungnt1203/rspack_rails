import { useState } from "react"

// Render it from a view with: <%= react_component "Hello", name: "World" %>
export default function Hello({ name }) {
  const [count, setCount] = useState(0)

  return (
    <div>
      <p>Hello, {name}!</p>
      <button type="button" onClick={() => setCount(count + 1)}>
        Clicked {count} times
      </button>
    </div>
  )
}
