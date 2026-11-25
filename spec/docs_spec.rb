# frozen_string_literal: true

# Code the docs tell people to copy is the code the gem writes or tests, so
# the two cannot drift apart, and every link in them goes somewhere.
RSpec.describe "docs" do
  let(:root) { File.expand_path("..", __dir__) }

  it "shows the controllers/index.js that rspack:migrate writes" do
    guide = File.read(File.join(root, "docs/guide.md"))
    index = File.read(File.join(root, "lib/install/controllers_index.js"))
    expect(guide).to include(index)
  end

  it "links only to files and headings that exist" do
    files = Dir[File.join(root, "docs/*.md")] + %w[README.md CONTRIBUTING.md].map { |f| File.join(root, f) }
    slug = ->(title) { title.downcase.delete("`").gsub(/[^\p{L}\p{N}\s_-]/u, "").strip.gsub(/\s/, "-") }
    anchors = files.to_h { |file| [file, File.read(file).scan(/^#+ (.+)$/).flatten.map(&slug)] }

    broken = files.flat_map do |file|
      File.read(file).scan(/\]\(([^)#\s]*)(?:#([^)\s]*))?\)/).filter_map do |path, anchor|
        next if path.match?(/\Ahttps?:|\Amailto:/)

        target = path.empty? ? file : File.expand_path(path, File.dirname(file))
        relative = file.delete_prefix("#{root}/")
        next "#{relative}: no file #{path}" unless File.exist?(target)
        next unless anchor && target.end_with?(".md") && !anchors.fetch(target, []).include?(anchor)

        "#{relative}: no heading ##{anchor} in #{target.delete_prefix("#{root}/")}"
      end
    end
    expect(broken).to eq([])
  end
end
