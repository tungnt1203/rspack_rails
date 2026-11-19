# frozen_string_literal: true

# Writes src/: N React + TypeScript components in a binary tree, each with
# state, lodash-es and date-fns, and an entry that renders the root.
#
#   ruby generate.rb 1000

require "fileutils"

count = Integer(ARGV.fetch(0, 1000))
FileUtils.rm_rf("src")

def component(index, count)
  kids = [(2 * index) + 1, (2 * index) + 2].select { |kid| kid < count }
  imports = kids.map { |kid| %(import C#{kid} from "../group#{kid / 100}/C#{kid}";) }.join("\n")
  children = kids.map { |kid| "<C#{kid} depth={depth + 1} />" }.join("\n      ")
  <<~TSX
    import { useState } from "react";
    import { chunk, sum } from "lodash-es";
    import { format, addDays } from "date-fns";
    #{imports}

    type Props = { depth?: number; label?: string };

    export default function C#{index}({ depth = 0, label = "c#{index}" }: Props) {
      const [count, setCount] = useState(#{index});
      const rows = chunk([count, #{index}, depth, #{index % 7}], 2).map((row) => sum(row));
      const day = format(addDays(new Date(2026, 0, 1), #{index % 365}), "yyyy-MM-dd");
      return (
        <section data-component="#{index}" title={label}>
          <button onClick={() => setCount(count + 1)}>{label}: {count}</button>
          <span>{day} {rows.join(", ")}</span>
          #{children}
        </section>
      );
    }
  TSX
end

count.times do |index|
  dir = "src/components/group#{index / 100}"
  FileUtils.mkdir_p(dir)
  File.write("#{dir}/C#{index}.tsx", component(index, count))
end

File.write("src/application.tsx", <<~TSX)
  import { createRoot } from "react-dom/client";
  import C0 from "./components/group0/C0";
  createRoot(document.getElementById("root")!).render(<C0 />);
TSX

puts "Wrote #{count} components to src/"
