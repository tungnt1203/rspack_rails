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
    it "passes and updates config/rspack/rails.mjs when rspack.config.mjs builds on it" do
      write("rspack.config.mjs", %(import { railsConfig } from "./config/rspack/rails.mjs";))
      write("config/rspack/rails.mjs", "// old")
      expect { host.require_config!("Sass") }.not_to raise_error
      expect(@root.join("config/rspack/rails.mjs").read).to eq(RspackRails::ManagedFile::BASE.content)
    end

    it "exits when rspack.config.mjs does not build on config/rspack/rails.mjs, even if it has the feature" do
      write("rspack.config.mjs", "sass-loader")
      expect { host.require_config!("Sass") }.to raise_error(SystemExit)
    end
  end

  describe "#install_rspack_config" do
    it "writes both config files in a new app" do
      host.install_rspack_config
      expect(RspackRails::RspackConfig.managed?(@root)).to be(true)
      expect(RspackRails::ManagedFile::BASE.current?(@root)).to be(true)
    end

    it "keeps an app's own rspack.config.mjs that builds on the base" do
      custom = %(import { railsConfig } from "./config/rspack/rails.mjs";\nexport default railsConfig(); // mine\n)
      write("rspack.config.mjs", custom)
      host.install_rspack_config
      expect(@root.join("rspack.config.mjs").read).to eq(custom)
      expect(RspackRails::ManagedFile::BASE.current?(@root)).to be(true)
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

  describe "#import_from_entry" do
    it "puts a stylesheet first and other modules last, once" do
      write("app/javascript/application.js", %(import "@hotwired/turbo-rails"\n))
      host.import_from_entry("app/javascript/application.js", "./application.css", first: true)
      host.import_from_entry("app/javascript/application.js", "./components/mount")
      host.import_from_entry("app/javascript/application.js", "./application.css", first: true)
      expect(@root.join("app/javascript/application.js").read)
        .to eq(%(import "./application.css"\nimport "@hotwired/turbo-rails"\nimport "./components/mount"\n))
    end

    it "counts an import written with single quotes and a semicolon" do
      write("app/javascript/application.js", %(import './application.css';\n))
      host.import_from_entry("app/javascript/application.js", "./application.css", first: true)
      expect(@root.join("app/javascript/application.js").read).to eq(%(import './application.css';\n))
    end
  end

  describe "#remove_css_gem" do
    it "drops the watcher, the old output and the gem" do
      write("Gemfile", %(source "https://rubygems.org"\n# Use Tailwind CSS\ngem "tailwindcss-rails"\n))
      write("Procfile.dev", "web: bin/rails server\ncss: bin/rails tailwindcss:watch\n")
      write("app/assets/builds/tailwind.css", "")
      write("app/assets/builds/tailwind/extra.css", "")
      allow(host).to receive(:run)

      host.remove_css_gem("tailwindcss-rails", watcher: "tailwindcss:watch",
                                               outputs: %w[app/assets/builds/tailwind.css app/assets/builds/tailwind])

      expect(@root.join("Procfile.dev").read).to eq("web: bin/rails server\n")
      expect(@root.join("app/assets/builds/tailwind.css")).not_to exist
      expect(@root.join("app/assets/builds/tailwind")).not_to exist
      expect(@root.join("Gemfile").read).to eq(%(source "https://rubygems.org"\n))
      expect(host).to have_received(:run).with("bundle install --quiet", abort_on_failure: true)
    end
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

    it "lists the app's own stylesheets by name, in the order :app linked them" do
      write("app/assets/stylesheets/application.css")
      write("app/assets/stylesheets/driver.css")
      write("app/assets/stylesheets/admin/print.css")
      host.replace_app_stylesheets_tag
      expect(@root.join(layout).read)
        .to include(%(<%= stylesheet_link_tag "admin/print", "application", "driver", "data-turbo-track": "reload" %>))
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
      expect { described_class.run("sass") }.to raise_error(RspackRails::Error, "rspack:install:sass failed")
    end
  end
end
