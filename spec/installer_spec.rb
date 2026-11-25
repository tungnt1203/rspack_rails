# frozen_string_literal: true

require "json"
require "stringio"
require "thor"
require "tmpdir"
require "rspack_rails/installer"

RSpec.describe RspackRails::Installer do
  # Stands in for the Rails generator that runs an application template.
  let(:host_class) do
    Class.new(Thor) do
      include Thor::Actions
      include RspackRails::Installer
    end
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      Dir.chdir(dir) { example.run }
    end
  end

  let(:quiet_shell) do
    Class.new(Thor::Shell::Basic) do
      def stdout = (@stdout ||= StringIO.new)
      def stderr = stdout
    end
  end

  let(:host) { host_class.new([], {}, destination_root: @root.to_s, shell: quiet_shell.new) }

  def write(path, content = "")
    file = @root.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  it "removes a gem and the comment above it" do
    write("Gemfile", %(gem "rails"\n# Use Tailwind CSS\ngem "tailwindcss-rails"\ngem "puma"\n))
    host.remove_gem("tailwindcss-rails")
    expect(@root.join("Gemfile").read).to eq(%(gem "rails"\ngem "puma"\n))
  end

  it "rewrites package.json" do
    write("package.json", JSON.generate(name: "app"))
    host.update_package_json { |package| package["scripts"] = { "build" => "rspack build" } }
    expect(JSON.parse(@root.join("package.json").read)).to eq("name" => "app",
                                                              "scripts" => { "build" => "rspack build" })
  end

  describe "#add_stylesheet_tag" do
    it "adds the tag before </head> once" do
      write("app/views/layouts/application.html.erb", "<head>\n  </head>\n")
      2.times { host.add_stylesheet_tag }
      expect(@root.join("app/views/layouts/application.html.erb").read.scan("rspack_stylesheet_tag").size).to eq(1)
    end

    it "uses Slim syntax in a Slim layout" do
      write("app/views/layouts/application.html.slim", "html\n  head\n    title App\n  body\n    == yield\n")
      host.add_stylesheet_tag
      expect(@root.join("app/views/layouts/application.html.slim").read).to eq(
        "html\n  head\n    title App\n    " \
        "= rspack_stylesheet_tag \"application\", \"data-turbo-track\": \"reload\"\n  body\n    == yield\n"
      )
    end
  end

  it "removes a helper from every layout, whatever the syntax" do
    write("app/views/layouts/application.html.erb", "<head>\n    <%= javascript_importmap_tags %>\n</head>\n")
    write("app/views/layouts/admin.html.haml", "%head\n  = javascript_importmap_tags\n  = csrf_meta_tags\n")
    host.remove_from_layouts("javascript_importmap_tags")
    expect(@root.join("app/views/layouts/application.html.erb").read).to eq("<head>\n</head>\n")
    expect(@root.join("app/views/layouts/admin.html.haml").read).to eq("%head\n  = csrf_meta_tags\n")
  end

  describe "#replace_in_layouts" do
    let(:tag) { %(rspack_javascript_tag "application") }

    it "puts the tag where each layout and layout partial had the helper" do
      write("app/views/layouts/application.html.erb", "<head>\n    <%= javascript_importmap_tags %>\n</head>\n")
      write("app/views/layouts/admin.html.haml", "%head\n  = javascript_importmap_tags\n  = csrf_meta_tags\n")
      write("app/views/layouts/_head.html.erb", "<%= javascript_importmap_tags %>\n")
      host.replace_in_layouts("javascript_importmap_tags", tag)
      expect(@root.join("app/views/layouts/application.html.erb").read).to eq("<head>\n    <%= #{tag} %>\n</head>\n")
      expect(@root.join("app/views/layouts/admin.html.haml").read).to eq("%head\n  = #{tag}\n  = csrf_meta_tags\n")
      expect(@root.join("app/views/layouts/_head.html.erb").read).to eq("<%= #{tag} %>\n")
    end

    it "removes a call with arguments, which may load another entry" do
      write("app/views/layouts/admin.html.erb", %(<head>\n  <%= javascript_importmap_tags "admin" %>\n</head>\n))
      host.replace_in_layouts("javascript_importmap_tags", tag)
      expect(@root.join("app/views/layouts/admin.html.erb").read).to eq("<head>\n</head>\n")
    end
  end

  describe "#add_stylesheet_tag" do
    let(:script) { %(<%= rspack_javascript_tag "application", "data-turbo-track": "reload" %>) }
    let(:stylesheet) { %(<%= rspack_stylesheet_tag "application", "data-turbo-track": "reload" %>) }

    it "links the CSS next to every layout's application script" do
      write("app/views/layouts/application.html.erb", "<head>\n    #{script}\n</head>\n")
      write("app/views/layouts/admin.html.erb", "<head>\n  #{script}\n</head>\n")
      write("app/views/layouts/mailer.html.erb", "<head>\n</head>\n")
      host.add_stylesheet_tag
      expect(@root.join("app/views/layouts/application.html.erb").read)
        .to eq("<head>\n    #{script}\n    #{stylesheet}\n</head>\n")
      expect(@root.join("app/views/layouts/admin.html.erb").read)
        .to eq("<head>\n  #{script}\n  #{stylesheet}\n</head>\n")
      expect(@root.join("app/views/layouts/mailer.html.erb").read).to eq("<head>\n</head>\n")
    end

    it "adds nothing to the layout when the <head> partial it renders has both tags" do
      write("app/views/layouts/application.html.erb", %(<head>\n  <%= render "layouts/head" %>\n</head>\n))
      write("app/views/layouts/_head.html.erb", "#{script}\n")
      host.add_stylesheet_tag
      expect(@root.join("app/views/layouts/_head.html.erb").read).to eq("#{script}\n#{stylesheet}\n")
      expect(@root.join("app/views/layouts/application.html.erb").read).not_to include("rspack_stylesheet_tag")
    end
  end

  it "does not add a tag to the layout when a layout partial it renders has it" do
    write("app/views/layouts/application.html.erb", %(<head>\n  <%= render "layouts/head" %>\n</head>\n))
    write("app/views/layouts/_head.html.erb", %(<%= rspack_javascript_tag "application" %>\n))
    host.add_to_layout(%(rspack_javascript_tag "application"), marker: "rspack_javascript_tag")
    expect(@root.join("app/views/layouts/application.html.erb").read).not_to include("rspack_javascript_tag")
  end

  describe ".run" do
    it "raises with the task name when the template fails" do
      allow(described_class).to receive(:system).and_return(false)
      expect { described_class.run("migrate") }.to raise_error(RspackRails::Error, "rspack:install:migrate failed")
    end
  end
end
