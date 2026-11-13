# frozen_string_literal: true

require "tmpdir"
require "rspack_rails/layouts"

RSpec.describe RspackRails::Layouts do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  def write(path, content = "")
    file = @root.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  it "lists every layout format with application first" do
    write("app/views/layouts/admin.html.erb")
    write("app/views/layouts/application.html.slim")
    write("app/views/layouts/mailer.text.erb")
    expect(described_class.all(@root)).to eq(
      %w[app/views/layouts/application.html.slim app/views/layouts/admin.html.erb]
    )
    expect(described_class.main(@root)).to eq("app/views/layouts/application.html.slim")
  end

  it "writes a helper call in the layout's syntax" do
    expect(described_class.tag("a.html.erb", "x")).to eq("<%= x %>")
    expect(described_class.tag("a.html.haml", "x")).to eq("= x")
  end

  describe ".insert_in_head" do
    it "adds a line before </head> in ERB" do
      content = "<html>\n  <head>\n    <title>App</title>\n  </head>\n</html>\n"
      expect(described_class.insert_in_head("a.html.erb", content, "x")).to eq(
        "<html>\n  <head>\n    <title>App</title>\n    <%= x %>\n  </head>\n</html>\n"
      )
    end

    it "adds a line after the last child of %head in Haml" do
      content = "%html\n  %head\n    %title App\n    = csrf_meta_tags\n\n  %body= yield\n"
      expect(described_class.insert_in_head("a.html.haml", content, "x")).to eq(
        "%html\n  %head\n    %title App\n    = csrf_meta_tags\n    = x\n\n  %body= yield\n"
      )
    end

    it "handles an empty head at the end of a Slim file" do
      expect(described_class.insert_in_head("a.html.slim", "html\n  head", "x")).to eq("html\n  head\n    = x\n")
    end

    it "returns nil without a head" do
      expect(described_class.insert_in_head("a.html.erb", "<div></div>", "x")).to be_nil
      expect(described_class.insert_in_head("a.html.slim", "div", "x")).to be_nil
    end
  end
end
