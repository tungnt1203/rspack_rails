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
File.write("package.json", "#{JSON.pretty_generate(package)}\n")

include_tag = %(<%= javascript_include_tag "application", "data-turbo-track": "reload", defer: true %>)
layout = Rails.root.join("app/views/layouts/application.html.erb")
if layout.exist?
  content = File.read(layout)
  if content.include?("javascript_importmap_tags")
    say "Found javascript_importmap_tags in your layout. Remove it if you are replacing importmap with rspack.",
        :yellow
  end
  unless content.include?('javascript_include_tag "application"')
    say "Adding javascript_include_tag to application layout"
    insert_into_file layout, "    #{include_tag}\n",
                     before: %r{^[ \t]*</head>}
  end
else
  say "Add this to your layout: #{include_tag}", :yellow
end

say "Configuring bin/dev"
if File.exist?("Procfile.dev")
  unless File.read("Procfile.dev").include?("js:")
    append_to_file "Procfile.dev",
                   "js: #{pm.run_command("build:watch")}\n"
  end
else
  create_file "Procfile.dev", "web: env RUBY_DEBUG_OPEN=true bin/rails server\njs: #{pm.run_command("build:watch")}\n"
end

unless File.exist?("bin/dev") && File.read("bin/dev").include?("Procfile.dev")
  copy_file "#{__dir__}/dev", "bin/dev", force: true
  chmod "bin/dev", 0o755, verbose: false
end

say "Installing @rspack/cli and @rspack/core"
run pm.add_dev_command("@rspack/cli", "@rspack/core")

say "rspack_rails installed. Run bin/dev to start developing.", :green
