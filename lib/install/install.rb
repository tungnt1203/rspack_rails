# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install`.
require "json"

pm = RspackRails::PackageManager.detect(Rails.root)

say "Creating app/assets/builds"
empty_directory "app/assets/builds"
create_file "app/assets/builds/.keep", "" unless File.exist?("app/assets/builds/.keep")

if File.exist?(".gitignore") && !File.read(".gitignore").include?("/app/assets/builds/*")
  append_to_file ".gitignore", "\n/app/assets/builds/*\n!/app/assets/builds/.keep\n/node_modules\n"
end

if Rails.root.join("app/assets/config/manifest.js").exist?
  append_to_file "app/assets/config/manifest.js", %(//= link_tree ../builds\n)
end

say "Creating rspack entry point"
unless File.exist?("app/javascript/application.js")
  copy_file "#{__dir__}/application.js",
            "app/javascript/application.js"
end
copy_file "#{__dir__}/rspack.config.mjs", "rspack.config.mjs"

say "Configuring package.json"
copy_file "#{__dir__}/package.json", "package.json" unless File.exist?("package.json")
package = JSON.parse(File.read("package.json"))
package["scripts"] ||= {}
package["scripts"]["build"] = "rspack build"
package["scripts"]["build:watch"] = "rspack build --watch"
package["scripts"]["dev"] = "rspack serve"
File.write("package.json", "#{JSON.pretty_generate(package)}\n")

include_tag = %(<%= rspack_javascript_tag "application", "data-turbo-track": "reload" %>)
layout = Rails.root.join("app/views/layouts/application.html.erb")
if layout.exist?
  content = File.read(layout)
  if content.include?("javascript_importmap_tags")
    say "Found javascript_importmap_tags in your layout. Remove it if you are replacing importmap with rspack.",
        :yellow
  end
  if content.match?(/javascript_include_tag "application".*$/)
    say "Switching javascript_include_tag to rspack_javascript_tag"
    gsub_file layout, /<%= javascript_include_tag "application".*%>/, include_tag
  elsif !content.include?("rspack_javascript_tag")
    say "Adding rspack_javascript_tag to application layout"
    insert_into_file layout, "    #{include_tag}\n", before: %r{^[ \t]*</head>}
  end
else
  say "Add this to your layout: #{include_tag}", :yellow
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
run pm.add_dev_command("@rspack/cli", "@rspack/core", "@rspack/dev-server")

say "rspack_rails installed. Run bin/dev to start developing.", :green
