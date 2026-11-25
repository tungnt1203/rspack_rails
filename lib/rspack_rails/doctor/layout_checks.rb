# frozen_string_literal: true

require_relative "checks"
require_relative "../layouts"

module RspackRails
  class Doctor
    # Whether the layouts link rspack's scripts and stylesheets, and nothing
    # that would load them twice.
    class LayoutChecks < Checks
      def checks
        [layout_check, stylesheet_check]
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
        return if built_entries.dig("application", "css").to_a.empty?

        linked = layouts_including("rspack_stylesheet_tag")
        if linked.any?
          return Check.new(:ok, "Stylesheet", "#{names(linked)} #{verb(linked, "uses")} rspack_stylesheet_tag")
        end

        Check.new(:warn, "Stylesheet", "the application entry builds CSS that no layout links",
                  %(Add <%= rspack_stylesheet_tag "application" %> to your layout))
      end
    end
  end
end
