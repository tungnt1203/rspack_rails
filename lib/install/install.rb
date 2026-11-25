# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install`.
require "rspack_rails/installer"
extend RspackRails::Installer

pm = RspackRails::PackageManager.detect(Rails.root)

# Rspack writes to public/rspack, which Rails serves under /rspack/.
# Nothing in it is committed or shipped in a Docker build context.
{ ".gitignore" => "\n/public/rspack\n/node_modules\n", ".dockerignore" => "\n/public/rspack\n" }.each do |ignore, lines|
  next unless File.exist?(ignore) && !File.read(ignore).match?(%r{^/?public/rspack\b})

  say "Leaving public/rspack out of #{ignore}"
  append_to_file ignore, lines
end

# Left by rspack_rails 1.x, which built into the asset pipeline.
if File.exist?("app/assets/config/manifest.js")
  gsub_file "app/assets/config/manifest.js", %r{^//= link_tree \.\./builds\n}, ""
end
RspackRails::Entrypoints.legacy_outputs(Rails.root).each { |file| remove_file file.relative_path_from(Rails.root).to_s }

say "Creating rspack entry point"
# An existing application.ts (or .jsx, .tsx) is the entry; a new .js would shadow it.
unless RspackRails::Entrypoints.main_entry(Rails.root)
  copy_file "#{__dir__}/application.js", "app/javascript/application.js"
end
install_rspack_config

say "Configuring package.json"
copy_file "#{__dir__}/package.json", "package.json" unless File.exist?("package.json")
update_package_json do |package|
  scripts = package["scripts"] ||= {}
  scripts["build"] = "rspack build"
  scripts["build:watch"] = "rspack build --watch"
  scripts["dev"] = "rspack serve"
  # import "#/lib/utils" for app/javascript/lib/utils (Node.js subpath imports, which rspack resolves).
  (package["imports"] ||= {})["#/*"] ||= "./app/javascript/*"
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

configure_containers pm, port: RspackRails.config.dev_server_port

say "Installing @rspack/cli, @rspack/core and @rspack/dev-server (Rspack #{RspackRails::RspackVersion::MAJOR})"
rspack_packages = %w[@rspack/cli @rspack/core @rspack/dev-server].map { |name| RspackRails::RspackVersion.pin(name) }
run pm.add_dev_command(*rspack_packages), abort_on_failure: true

# rspack:migrate and template.rb (RSPACK_TEMPLATE) have more steps after this one.
unless @rspack_migrating || ENV["RSPACK_TEMPLATE"]
  say "rspack_rails installed. Run bin/dev to start developing.", :green
end
