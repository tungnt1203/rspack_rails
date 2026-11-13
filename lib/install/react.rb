# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:react`.
require "json"

pm = RspackRails::PackageManager.detect(Rails.root)
entry = %w[app/javascript/application.js app/javascript/application.ts].find { |file| File.exist?(file) }
typescript = File.exist?("tsconfig.json")

unless File.exist?("rspack.config.mjs") && File.read("rspack.config.mjs").include?("ReactRefreshRspackPlugin")
  say "rspack.config.mjs predates React support. Re-run `bin/rails rspack:install` and accept the new " \
      "rspack.config.mjs, then run this task again.", :red
  exit 1
end

if entry.nil?
  say "No app/javascript/application.{js,ts} found. Run `bin/rails rspack:install` first.", :red
  exit 1
end

say "Adding React component autoloading"
copy_file "#{__dir__}/react/mount.js", "app/javascript/components/mount.js", force: true
if Dir.glob("app/javascript/components/**/*.{jsx,tsx}").empty?
  hello = typescript ? "Hello.tsx" : "Hello.jsx"
  copy_file "#{__dir__}/react/#{hello}", "app/javascript/components/#{hello}"
end

unless File.read(entry).match?(%r{^import ["']\./components/mount["']})
  append_to_file entry, %(import "./components/mount"\n)
end

if typescript
  say "Setting \"jsx\": \"react-jsx\" in tsconfig.json"
  tsconfig = JSON.parse(File.read("tsconfig.json"))
  (tsconfig["compilerOptions"] ||= {})["jsx"] = "react-jsx"
  include = tsconfig["include"]
  include << "app/javascript/**/*.tsx" if include&.include?("app/javascript/**/*.ts") && include.none?(/\.tsx/)
  File.write("tsconfig.json", "#{JSON.pretty_generate(tsconfig)}\n")
end

say "Installing react and react-dom"
run pm.add_command("react", "react-dom"), abort_on_failure: true

dev_packages = %w[@rspack/plugin-react-refresh react-refresh]
dev_packages += %w[@types/react @types/react-dom] if typescript
say "Installing #{dev_packages.join(", ")}"
run pm.add_dev_command(*dev_packages), abort_on_failure: true

tag = '<%= react_component "Hello", name: "World" %>'
say "React ready. Render a component from app/javascript/components with #{tag}. " \
    "Restart the dev server to enable Fast Refresh.", :green
