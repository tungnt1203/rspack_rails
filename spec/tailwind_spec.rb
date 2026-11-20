# frozen_string_literal: true

require "rspack_rails/tailwind"

RSpec.describe RspackRails::Tailwind do
  it "adds the excludes right after @import \"tailwindcss\"" do
    css = described_class.add_excludes(%(@import "tailwindcss";\n\n.btn { color: red; }\n))
    expect(css).to start_with(%(@import "tailwindcss";\n\n/* Not scanned))
    expect(css).to include(%(@source not "../../tmp";\n), %(@source not "../assets/builds";\n))
    expect(css).to end_with(%(\n.btn { color: red; }\n))
  end

  it "keeps the options of the import" do
    css = described_class.add_excludes(%(@import "tailwindcss" source("../..");\n))
    expect(css).to start_with(%(@import "tailwindcss" source("../..");\n\n/* Not scanned))
  end

  it "adds them once" do
    once = described_class.add_excludes(%(@import "tailwindcss";\n))
    expect(described_class.add_excludes(once)).to eq(once)
    expect(described_class.excludes?(once)).to be(true)
  end

  it "leaves a stylesheet without Tailwind alone" do
    expect(described_class.add_excludes("body { margin: 0; }\n")).to eq("body { margin: 0; }\n")
    expect(described_class.imports_tailwind?("body { margin: 0; }\n")).to be(false)
  end
end
