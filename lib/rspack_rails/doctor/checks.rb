# frozen_string_literal: true

require "forwardable"

module RspackRails
  class Doctor
    # A group of related checks. #checks returns them in report order; a check
    # that does not apply to the app is nil.
    class Checks
      extend Forwardable

      def_delegators :@context, :app, :root, :config, :dev_server, :node_version, :installed_package,
                     :node_modules_package, :package_json, :layouts, :layouts_including, :entrypoints,
                     :package_manager, :built_entries, :exist?, :read

      def initialize(context)
        @context = context
      end

      def checks
        raise NotImplementedError
      end

      private

      # "application.html.erb, admin.html.slim"
      def names(paths)
        paths.map { |path| File.basename(path) }.join(", ")
      end

      # "uses" for one layout, "use" for several.
      def verb(paths, singular)
        paths.one? ? singular : singular.delete_suffix("s")
      end
    end
  end
end
