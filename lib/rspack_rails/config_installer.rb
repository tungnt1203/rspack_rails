# frozen_string_literal: true

require_relative "rspack_config"

module RspackRails
  # Installer steps for the two rspack config files (see RspackConfig). Part of
  # RspackRails::Installer, so they run inside a Rails generator with Thor actions.
  module ConfigInstaller
    # Writes config/rspack/rails.mjs and, unless the app already has one built
    # on it, rspack.config.mjs. Any other rspack.config.mjs is replaced after
    # asking (Thor shows a diff on "d").
    def install_rspack_config
      sync_rspack_config
      return if RspackConfig.managed?(destination_root)

      if rspack_app.file?(RspackConfig::APP)
        say "rspack.config.mjs now builds on #{RspackConfig::BASE}, which rspack_rails updates on its own. " \
            "Accept the new file, then move your changes into its railsConfig callback.", :yellow
      end
      create_file RspackConfig::APP, File.read(File.expand_path("../install/rspack.config.mjs", __dir__))
    end

    # Exits unless rspack.config.mjs builds on config/rspack/rails.mjs, which
    # supports every feature once it is current.
    def require_config!(feature)
      return sync_rspack_config if RspackConfig.managed?(destination_root)

      say "rspack.config.mjs does not build on #{RspackConfig::BASE}, which #{feature} needs. Re-run " \
          "`bin/rails rspack:install` and accept the new rspack.config.mjs, then run this task again.", :red
      exit 1
    end

    # config/rspack/rails.mjs and the other files rspack_rails keeps up to date.
    def sync_rspack_config
      ManagedFile.sync_all(destination_root).each { |result| report_sync(result) }
    end

    # Writes a managed file (ManagedFile::STIMULUS, ::REACT) for its installer.
    def install_managed_file(file)
      report_sync(file.sync(destination_root, create: true))
    end

    def report_sync(result)
      return unless result.written

      say "Writing #{result.path} for rspack_rails #{VERSION}"
      file = ManagedFile::ALL.find { |managed| managed.path == result.path }
      say file.edits_message(result.backup), :yellow if result.backup
    end
  end
end
