# frozen_string_literal: true

# Rails application template: a new app bundled with rspack_rails.
#
#   rails new myapp -m https://raw.githubusercontent.com/tungnt1203/rspack_rails/main/template.rb
#
# Works with the default `rails new` (importmap, migrated to rspack) and with
# --skip-javascript, -j esbuild, --css tailwind or --css sass. It asks which
# extras to set up; answer without prompts by listing them:
#
#   RSPACK_FEATURES=stimulus,typescript,tailwind rails new myapp -m .../template.rb
#   RSPACK_FEATURES=none rails new myapp -m .../template.rb
#
# Features: stimulus, typescript, react, tailwind, sass.

FEATURES = {
  "stimulus" => "Stimulus with controller autoloading",
  "typescript" => "TypeScript type checking",
  "react" => "React with Fast Refresh",
  "tailwind" => "Tailwind CSS v4",
  "sass" => "Sass"
}.freeze

# RSPACK_RAILS_PATH points at a local checkout (used by this gem's own CI).
if ENV["RSPACK_RAILS_PATH"]
  gem "rspack_rails", path: ENV["RSPACK_RAILS_PATH"]
else
  gem "rspack_rails"
end

# --css tailwind / --css sass already chose the stylesheet tool.
preset = []
preset << "tailwind" if File.read("Gemfile").include?("tailwindcss-rails")
preset << "sass" if File.read("Gemfile").include?("dartsass-rails")
preset << "stimulus" if File.exist?("app/javascript/controllers/application.js")

features =
  if ENV["RSPACK_FEATURES"]
    ENV["RSPACK_FEATURES"].split(",").map(&:strip) - ["none", ""]
  else
    FEATURES.filter_map do |name, label|
      next name if preset.include?(name)

      name if yes?("Add #{label}? (y/N)")
    end
  end
unknown = features - FEATURES.keys
raise Thor::Error, "Unknown RSPACK_FEATURES: #{unknown.join(", ")} (use #{FEATURES.keys.join(", ")})" if unknown.any?

# In the order above: TypeScript before React, so React gets .tsx and @types/react.
features = FEATURES.keys & (features | preset)

after_bundle do
  if File.exist?("config/importmap.rb") || File.read("Gemfile").include?("jsbundling-rails")
    # rspack:migrate refuses to run on a dirty git tree; a new app is all uncommitted.
    run "FORCE=1 bin/rails rspack:migrate", abort_on_failure: true
  else
    rails_command "rspack:install", abort_on_failure: true
  end

  features.each { |feature| rails_command "rspack:install:#{feature}", abort_on_failure: true }

  rails_command "rspack:build", abort_on_failure: true
  say
  say "rspack_rails is set up#{" with #{features.join(", ")}" if features.any?}. Run bin/dev to start.", :green
end
