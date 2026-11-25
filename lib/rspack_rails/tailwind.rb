# frozen_string_literal: true

module RspackRails
  # Tailwind CSS v4 finds class names by scanning the app, and skips what
  # .gitignore lists. A Docker build has no .gitignore (Rails' .dockerignore
  # leaves it out) but does have bootsnap's cache in tmp/, so it scanned that
  # too and the production CSS grew unused classes. The stylesheet leaves out
  # Rails' runtime files and rspack's own output by name instead.
  module Tailwind
    STYLESHEET = "app/javascript/application.css"
    IMPORT = /^@import\s+["']tailwindcss["'][^\n]*\n/
    # Relative to STYLESHEET.
    EXCLUDES = <<~CSS
      /* Not scanned for class names. Tailwind skips what .gitignore lists, but a
         Docker build has no .gitignore. */
      @source not "../../tmp";
      @source not "../../log";
      @source not "../../storage";
      @source not "../../public/rspack";
    CSS

    module_function

    def imports_tailwind?(css)
      css.match?(IMPORT)
    end

    def excludes?(css)
      css.include?(%(@source not "../../tmp"))
    end

    # The stylesheet with EXCLUDES after its @import "tailwindcss".
    def add_excludes(css)
      return css if excludes?(css) || !imports_tailwind?(css)

      css.sub(IMPORT) { |import| "#{import}\n#{EXCLUDES}" }
    end
  end
end
