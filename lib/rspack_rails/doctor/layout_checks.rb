# frozen_string_literal: true

require_relative "checks"
require_relative "../layouts"

module RspackRails
  class Doctor
    # Whether the layouts link rspack's scripts and stylesheets, and nothing
    # that would load them twice.
    class LayoutChecks < Checks
      def checks
        [layout_check, stylesheet_check, app_stylesheets_check]
      end

      private

      def layout_check
        return Check.new(:warn, "Layout", "no layout found in #{Layouts::DIR}") if layouts.empty?

        importmap = layouts_including("javascript_importmap_tags")
        if importmap.any?
          return Check.new(:warn, "Layout", "#{names(importmap)} still includes javascript_importmap_tags",
                           "Remove it if rspack replaces importmap, or the app may load JavaScript twice")
        end
        rspack = layouts_including("rspack_javascript_tag")
        return Check.new(:ok, "Layout", "#{names(rspack)} #{verb(rspack, "uses")} rspack_javascript_tag") if rspack.any?

        missing_layout_tag_check
      end

      def missing_layout_tag_check
        tag = Layouts.tag(layouts.first, 'rspack_javascript_tag "application"')
        Check.new(:warn, "Layout", "no layout uses rspack_javascript_tag",
                  "Add #{tag} to #{layouts.first} to get the dev server and HMR")
      end

      def stylesheet_check
        return unless exist?("app/assets/builds/application.bundle.css")

        linked = layouts_including("rspack_stylesheet_tag")
        if linked.any?
          return Check.new(:ok, "Stylesheet", "#{names(linked)} #{verb(linked, "uses")} rspack_stylesheet_tag")
        end

        Check.new(:warn, "Stylesheet", "application.bundle.css is built but not linked",
                  %(Add <%= rspack_stylesheet_tag "application" %> to your layout))
      end

      # `stylesheet_link_tag :app` links rspack's bundles too, without their options.
      def app_stylesheets_check
        return if Dir.glob("app/assets/builds/*.bundle.css", base: root).empty?

        linking = layouts.select { |path| read(path).match?(Layouts::APP_STYLESHEETS) }
        return if linking.empty?

        Check.new(:warn, "Stylesheet", "#{names(linking)} #{verb(linking, "links")} rspack's bundles again through " \
                                       "stylesheet_link_tag :app",
                  %(Use stylesheet_link_tag "application" (or list your own stylesheets); ) +
                  "a print or admin bundle otherwise applies on every page")
      end
    end
  end
end
