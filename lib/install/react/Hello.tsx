import { useState } from "react"

type Props = { name: string }

// Render it from a view with: <%= react_component "Hello", name: "World" %>
export default function Hello({ name }: Props) {
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
