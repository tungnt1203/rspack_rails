# frozen_string_literal: true

# Code the docs tell people to copy is the code the gem writes or tests, so
# the two cannot drift apart.
RSpec.describe "docs" do
  let(:root) { File.expand_path("..", __dir__) }

  it "shows the controllers/index.js that rspack:migrate writes" do
    guide = File.read(File.join(root, "docs/guide.md"))
    index = File.read(File.join(root, "lib/install/controllers_index.js"))
    expect(guide).to include(index)
  end
end
