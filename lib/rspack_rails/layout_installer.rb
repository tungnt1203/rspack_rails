# frozen_string_literal: true

require_relative "layouts"

module RspackRails
  # Installer steps that edit the app's layouts and layout partials. Part of
  # RspackRails::Installer, so they run inside a Rails generator with Thor actions.
  module LayoutInstaller
    STYLESHEET_TAG = %(rspack_stylesheet_tag "application", "data-turbo-track": "reload")
    APPLICATION_SCRIPT = /^[ \t]*(?:<%=|=)[ \t]*rspack_javascript_tag[ (]"application".*$/

    # app/views/layouts/application.html.{erb,slim,haml}, or nil.
    def layout
      Layouts.main(destination_root)
    end

    # Adds `code` (a helper call) to the end of <head> in the application
    # layout, unless the layout or a layout partial it renders mentions `marker`.
    def add_to_layout(code, marker:)
      path = layout
      return say("Add this to your layout: <%= #{code} %>", :yellow) unless path
      return if Layouts.content_with_partials(destination_root, path).include?(marker)

      updated = Layouts.insert_in_head(path, rspack_app.read(path), code)
      return say("Add this to the <head> of #{path}: #{Layouts.tag(path, code)}", :yellow) unless updated

      say "Adding #{marker} to #{path}"
      rspack_app.path(path).write(updated)
    end

    # rspack_stylesheet_tag "application" right after every rspack_javascript_tag
    # "application", so each layout (or <head> partial) that loads the bundle
    # gets its CSS; in the application layout when none has the script tag.
    def add_stylesheet_tag
      files = layouts_matching(APPLICATION_SCRIPT).reject { |path| linked_stylesheet?(path) }
      return add_to_layout(STYLESHEET_TAG, marker: "rspack_stylesheet_tag") if files.empty?

      files.each do |path|
        say "Adding rspack_stylesheet_tag to #{path}"
        tag = Layouts.tag(path, STYLESHEET_TAG)
        gsub_file(path, APPLICATION_SCRIPT, verbose: false) { |line| "#{line}\n#{Layouts.leading_space(line)}#{tag}" }
      end
    end

    # Puts `code` where each layout (or layout partial) calls `helper` with no
    # arguments, keeping its place and indentation. A call with arguments may
    # load something else: it is removed, with a note.
    def replace_in_layouts(helper, code)
      layouts_matching(helper_call(helper)).each do |path|
        say "Replacing #{helper} with #{code[/\A\w+/]} in #{path}"
        bare = /^[ \t]*(?:<%=[ \t]*#{helper}[ \t]*%>|=[ \t]*#{helper}[ \t]*)$/
        gsub_file(path, bare, verbose: false) { |line| "#{Layouts.leading_space(line)}#{Layouts.tag(path, code)}" }
        next unless rspack_app.read(path).match?(helper_call(helper))

        say "#{path} calls #{helper} with arguments, so it is removed. Add the rspack tag for that entry by hand.",
            :yellow
        gsub_file path, /#{helper_call(helper).source}.*\n/, ""
      end
    end

    # Removes lines that call `helper` (ERB, Slim or Haml) from every layout.
    def remove_from_layouts(helper)
      layouts_matching(helper_call(helper)).each { |path| gsub_file path, /#{helper_call(helper).source}.*\n/, "" }
    end

    private

    def layouts_matching(pattern)
      rspack_app.layouts.select { |path| rspack_app.read(path).match?(pattern) }
    end

    def linked_stylesheet?(path)
      rspack_app.read(path).include?("rspack_stylesheet_tag")
    end

    def helper_call(helper)
      /^[ \t]*(?:<%=|=)[ \t]*#{helper}(?!\w)/
    end
  end
end
