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

  describe "#main_entry!" do
    it "finds a TypeScript entry" do
      write("app/javascript/application.ts")
      expect(host.main_entry!).to eq("app/javascript/application.ts")
    end

    it "exits when there is no entry" do
      expect { host.main_entry! }.to raise_error(SystemExit)
    end
  end

  describe "#require_config!" do
    it "passes when rspack.config.mjs mentions the marker" do
      write("rspack.config.mjs", "sass-loader")
      expect { host.require_config!("sass-loader", "Sass") }.not_to raise_error
    end

    it "exits when rspack.config.mjs predates the feature" do
      write("rspack.config.mjs", "")
      expect { host.require_config!("sass-loader", "Sass") }.to raise_error(SystemExit)
    end
  end

  it "removes a gem and the comment above it" do
    write("Gemfile", %(gem "rails"\n# Use Tailwind CSS\ngem "tailwindcss-rails"\ngem "puma"\n))
    expect(host.gem_in_gemfile?("tailwindcss-rails")).to be(true)
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

  describe "#replace_app_stylesheets_tag" do
    let(:layout) { "app/views/layouts/application.html.erb" }

    before do
      write(layout, <<~ERB)
        <head>
          <%# Includes all stylesheet files in app/assets/stylesheets %>
          <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
        </head>
      ERB
    end

    it "links application.css when that is the app's only stylesheet" do
      write("app/assets/stylesheets/application.css")
      host.replace_app_stylesheets_tag
      expect(@root.join(layout).read)
        .to eq(%(<head>\n  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>\n</head>\n))
    end

    it "drops the tag when the app has no stylesheets of its own" do
      host.replace_app_stylesheets_tag
      expect(@root.join(layout).read).to eq("<head>\n</head>\n")
    end

    it "leaves comments that mention stylesheet_link_tag :app alone" do
      write(layout, %(<%# not stylesheet_link_tag :app %>\n<%= stylesheet_link_tag "application" %>\n))
      expect { host.replace_app_stylesheets_tag }.not_to(change { @root.join(layout).read })
    end

    it "handles Slim" do
      slim = "app/views/layouts/application.html.slim"
      @root.join(layout).delete
      write(slim, "head\n  = stylesheet_link_tag :app\n")
      write("app/assets/stylesheets/application.css")
      host.replace_app_stylesheets_tag
      expect(@root.join(slim).read).to eq(%(head\n  = stylesheet_link_tag "application"\n))
    end

    it "leaves the layout alone when the app has several stylesheets" do
      write("app/assets/stylesheets/application.css")
      write("app/assets/stylesheets/admin.css")
      expect { host.replace_app_stylesheets_tag }.not_to(change { @root.join(layout).read })
    end
  end

  it "removes a helper from every layout, whatever the syntax" do
    write("app/views/layouts/application.html.erb", "<head>\n    <%= javascript_importmap_tags %>\n</head>\n")
    write("app/views/layouts/admin.html.haml", "%head\n  = javascript_importmap_tags\n  = csrf_meta_tags\n")
    host.remove_from_layouts("javascript_importmap_tags")
    expect(@root.join("app/views/layouts/application.html.erb").read).to eq("<head>\n</head>\n")
    expect(@root.join("app/views/layouts/admin.html.haml").read).to eq("%head\n  = csrf_meta_tags\n")
  end

  describe ".run" do
    it "raises with the task name when the template fails" do
      allow(described_class).to receive(:system).and_return(false)
      expect { described_class.run("sass") }.to raise_error(RspackRails::Error, "rspack:install:sass failed")
    end
  end
end
