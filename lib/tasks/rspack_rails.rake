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
  end

  desc "Install JavaScript dependencies"
  task :dependencies do
    command = RspackRails::PackageManager.detect(Rails.root).install_command
    system(command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
  end

  desc "Build JavaScript bundles with rspack"
  task build: :dependencies do
    command = RspackRails::PackageManager.detect(Rails.root).run_command("build")
    system(command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
  end

  desc "Remove rspack build output"
  task :clobber do
    Dir[Rails.root.join("app/assets/builds/**/*.{js,js.map,css,css.map}")].each { |f| File.delete(f) }
  end
end

unless ENV["SKIP_RSPACK_BUILD"]
  %w[assets:precompile test:prepare spec:prepare db:test:prepare].each do |name|
    Rake::Task[name].enhance(["rspack:build"]) if Rake::Task.task_defined?(name)
  end
end

Rake::Task["assets:clobber"].enhance(["rspack:clobber"]) if Rake::Task.task_defined?("assets:clobber")
