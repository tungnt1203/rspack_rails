# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install`.
require "rspack_rails/installer"
extend RspackRails::Installer

pm = RspackRails::PackageManager.detect(Rails.root)

say "Creating app/assets/builds"
empty_directory "app/assets/builds"
create_file "app/assets/builds/.keep", "" unless File.exist?("app/assets/builds/.keep")

if File.exist?(".gitignore") && !File.read(".gitignore").include?("/app/assets/builds/*")
  append_to_file ".gitignore", "\n/app/assets/builds/*\n!/app/assets/builds/.keep\n/node_modules\n"
end

manifest = Rails.root.join("app/assets/config/manifest.js")
if manifest.exist? && !manifest.read.include?("link_tree ../builds")
  append_to_file "app/assets/config/manifest.js", %(//= link_tree ../builds\n)
end

say "Creating rspack entry point"
# An existing application.ts (or .jsx, .tsx) is the entry; a new .js would shadow it.
unless RspackRails::Entrypoints.main_entry(Rails.root)
  copy_file "#{__dir__}/application.js", "app/javascript/application.js"
end
copy_file "#{__dir__}/rspack.config.mjs", "rspack.config.mjs"

say "Configuring package.json"
copy_file "#{__dir__}/package.json", "package.json" unless File.exist?("package.json")
update_package_json do |package|
  scripts = package["scripts"] ||= {}
  scripts["build"] = "rspack build"
  scripts["build:watch"] = "rspack build --watch"
  scripts["dev"] = "rspack serve"
end

js_tag = %(rspack_javascript_tag "application", "data-turbo-track": "reload")
if (layout = self.layout)
  content = File.read(layout)
  if content.include?("javascript_importmap_tags")
    say "Found javascript_importmap_tags in #{layout}. Remove it if you are replacing importmap with rspack.",
        :yellow
  end
  # <%= javascript_include_tag "application" ... %> in ERB, = javascript_include_tag ... in Slim/Haml.
  include_tag = if RspackRails::Layouts.erb?(layout)
                  /<%= javascript_include_tag "application".*%>/
                else
                  /=[ \t]*javascript_include_tag[ (]"application".*$/
                end
  if content.match?(include_tag)
    say "Switching javascript_include_tag to rspack_javascript_tag"
    gsub_file layout, include_tag, RspackRails::Layouts.tag(layout, js_tag)
  else
    add_to_layout js_tag, marker: "rspack_javascript_tag"
  end
else
  say "Add this to your layout: <%= #{js_tag} %>", :yellow
end

say "Configuring bin/dev"
js_process = "js: #{pm.run_command("dev")}"
if !File.exist?("Procfile.dev")
  create_file "Procfile.dev", "web: env RUBY_DEBUG_OPEN=true bin/rails server\n#{js_process}\n"
elsif File.read("Procfile.dev").match?(/^js: .*build:watch$/)
  gsub_file "Procfile.dev", /^js: .*build:watch$/, js_process
elsif !File.read("Procfile.dev").match?(/^js:/)
  append_to_file "Procfile.dev", "#{js_process}\n"
end

unless File.exist?("bin/dev") && File.read("bin/dev").include?("Procfile.dev")
  copy_file "#{__dir__}/dev", "bin/dev", force: true
  chmod "bin/dev", 0o755, verbose: false
end

say "Installing @rspack/cli, @rspack/core and @rspack/dev-server"
run pm.add_dev_command("@rspack/cli", "@rspack/core", "@rspack/dev-server"), abort_on_failure: true

say "rspack_rails installed. Run bin/dev to start developing.", :green
