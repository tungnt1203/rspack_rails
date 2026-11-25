# frozen_string_literal: true

module RspackRails
  # The Rspack major version the generated rspack.config.mjs is written and tested
  # for. Installers pin it, so a new app never picks up the next major on its
  # own, and rspack:doctor checks the installed packages against it.
  module RspackVersion
    MAJOR = 2

    module_function

    # "@rspack/core" -> "@rspack/core@^2", for add commands.
    def pin(package)
      "#{package}@^#{MAJOR}"
    end

    # :supported, :older or :newer, from an installed version such as "2.3.2".
    def compare(version)
      major = version.to_s[/\A\d+/].to_i
      return :supported if major == MAJOR

      major < MAJOR ? :older : :newer
    end
  end
end
