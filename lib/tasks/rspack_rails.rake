# frozen_string_literal: true

namespace :rspack do
  desc "Set up rspack in this Rails app"
  task :install do
    template = File.expand_path("../install/install.rb", __dir__)
    system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
      raise(RspackRails::Error, "rspack:install failed")
  end

  namespace :install do
    desc "Set up Stimulus with automatic controller registration"
    task :stimulus do
      template = File.expand_path("../install/stimulus.rb", __dir__)
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(RspackRails::Error, "rspack:install:stimulus failed")
    end

    desc "Set up TypeScript type checking (tsconfig.json, typescript, typecheck script)"
    task :typescript do
      template = File.expand_path("../install/typescript.rb", __dir__)
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(RspackRails::Error, "rspack:install:typescript failed")
    end

    desc "Set up React with Fast Refresh and the react_component helper"
    task :react do
      template = File.expand_path("../install/react.rb", __dir__)
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(RspackRails::Error, "rspack:install:react failed")
    end

    desc "Set up Sass (migrates from dartsass-rails)"
    task :sass do
      template = File.expand_path("../install/sass.rb", __dir__)
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(RspackRails::Error, "rspack:install:sass failed")
    end

    desc "Set up Tailwind CSS v4 (migrates from tailwindcss-rails)"
    task :tailwind do
      template = File.expand_path("../install/tailwind.rb", __dir__)
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(RspackRails::Error, "rspack:install:tailwind failed")
    end
  end

  desc "Migrate from importmap-rails or jsbundling-rails to rspack (FORCE=1 to skip the clean git check)"
  task :migrate do
    dirty = system("git", "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL) &&
            !`git status --porcelain`.strip.empty?
    if dirty && ENV["FORCE"].to_s.empty?
      raise RspackRails::Error,
            "rspack:migrate removes and rewrites files. Commit or stash your changes first, or run with FORCE=1."
    end

    template = File.expand_path("../install/migrate.rb", __dir__)
    system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
      raise(RspackRails::Error, "rspack:migrate failed")
  end

  desc "Check the rspack setup of this app"
  task doctor: :environment do
    require "rspack_rails/doctor"
    doctor = RspackRails::Doctor.new(Rails.root)
    doctor.report
    exit 1 unless doctor.ok?
  end

  desc "Install JavaScript dependencies"
  task :dependencies do
    command = RspackRails::PackageManager.detect(Rails.root).install_command
    system(command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
  end

  desc "Build JavaScript bundles with rspack"
  task build: :dependencies do
    command = RspackRails::PackageManager.detect(Rails.root).run_command("build")
    # `rspack build` defaults NODE_ENV to production. Development and test
    # builds keep source maps and skip minification; staging etc. stay production.
    node_env = Rails.env.development? || Rails.env.test? ? "development" : "production"
    env = { "NODE_ENV" => ENV.fetch("NODE_ENV", node_env) }
    system(env, command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
  end

  desc "Analyze the production bundle with Rsdoctor (report in tmp/rsdoctor)"
  task analyze: :dependencies do
    require "json"
    pm = RspackRails::PackageManager.detect(Rails.root)
    config = Rails.root.join("rspack.config.mjs")
    unless config.exist? && config.read.include?("RsdoctorRspackPlugin")
      raise RspackRails::Error,
            "rspack.config.mjs predates rspack:analyze. Re-run `bin/rails rspack:install` and accept the new config."
    end

    package = JSON.parse(Rails.root.join("package.json").read)
    unless package.fetch("devDependencies", {}).merge(package.fetch("dependencies", {})).key?("@rsdoctor/rspack-plugin")
      command = pm.add_dev_command("@rsdoctor/rspack-plugin")
      system(command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
    end

    command = pm.run_command("build")
    system({ "RSDOCTOR" => "true", "NODE_ENV" => "production" }, command, chdir: Rails.root) ||
      raise(RspackRails::Error, "#{command} failed")
    puts "Rsdoctor report: #{Rails.root.join("tmp/rsdoctor/rsdoctor-report.html")}"
  end

  desc "Remove rspack build output"
  task :clobber do
    patterns = %w[**/*.{js,js.map,css,css.map} **/*.digested.*].map { |p| Rails.root.join("app/assets/builds", p).to_s }
    Dir[*patterns].uniq.each { |f| FileUtils.rm_f(f) } # a lazy chunk matches both patterns
  end
end

unless ENV["SKIP_RSPACK_BUILD"]
  %w[assets:precompile test:prepare spec:prepare db:test:prepare].each do |name|
    Rake::Task[name].enhance(["rspack:build"]) if Rake::Task.task_defined?(name)
  end
end

Rake::Task["assets:clobber"].enhance(["rspack:clobber"]) if Rake::Task.task_defined?("assets:clobber")
