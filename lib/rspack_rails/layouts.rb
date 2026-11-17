# frozen_string_literal: true

require "pathname"

module RspackRails
  # Finds an app's layouts (ERB, Slim or Haml) and writes helper calls in
  # each one's syntax. Shared by the installers and the doctor.
  module Layouts
    DIR = "app/views/layouts"
    EXTENSIONS = %w[erb slim haml].freeze
    # Rails 8's default `stylesheet_link_tag :app` links every CSS file under
    # app/assets, rspack's app/assets/builds/*.bundle.css included. Only
    # output tags (`<%=` in ERB, `=` in Slim/Haml) count, not comments.
    APP_STYLESHEETS = /^([ \t]*(?:<%=|=)[ \t]*stylesheet_link_tag[ (]):app\b/

    module_function

    # Every page layout, relative to root, application.* first.
    def all(root)
      paths = Dir.glob("#{DIR}/*.html.{#{EXTENSIONS.join(",")}}", base: root.to_s).sort
      main = main(root)
      main ? [main, *(paths - [main])] : paths
    end

    # app/views/layouts/application.html.{erb,slim,haml}, or nil.
    def main(root)
      EXTENSIONS.map { |ext| "#{DIR}/application.html.#{ext}" }.find { |path| Pathname(root).join(path).file? }
    end

    def erb?(path)
      path.end_with?(".erb")
    end

    # The layout's content followed by that of the layout partials it renders
    # (`render "layouts/head"` reads app/views/layouts/_head.html.erb), so a
    # tag in a shared <head> partial counts as the layout's own.
    def content_with_partials(root, path, depth: 2)
      file = Pathname(root).join(path)
      return "" unless file.file?

      content = file.read
      return content if depth.zero?

      partials = content.scan(%r{render[ (]+(?:partial:\s*)?["']layouts/([\w/]+)["']}).flatten.uniq
      partials.reduce(content) do |all, name|
        partial = partial_path(root, name)
        partial ? "#{all}\n#{content_with_partials(root, partial, depth: depth - 1)}" : all
      end
    end

    # "site/header" -> app/views/layouts/site/_header.html.erb (or .slim, .haml), or nil.
    def partial_path(root, name)
      dir, base = File.split(name)
      prefix = dir == "." ? DIR : "#{DIR}/#{dir}"
      EXTENSIONS.map { |ext| "#{prefix}/_#{base}.html.#{ext}" }.find { |path| Pathname(root).join(path).file? }
    end

    # The names `stylesheet_link_tag` takes for the app's own stylesheets
    # (app/assets/stylesheets/admin/print.css -> "admin/print"), in the order
    # `stylesheet_link_tag :app` links them.
    def own_stylesheet_names(paths)
      paths.sort.map { |path| path.delete_prefix("app/assets/stylesheets/").delete_suffix(".css") }
    end

    # `rspack_javascript_tag "application"` as an output line in the layout's syntax.
    def tag(path, code)
      erb?(path) ? "<%= #{code} %>" : "= #{code}"
    end

    # The layout's content with `code` added at the end of <head>, or nil when
    # there is no head to add it to.
    def insert_in_head(path, content, code)
      if erb?(path)
        return unless content.match?(%r{^[ \t]*</head>})

        content.sub(%r{^([ \t]*)</head>}) { "#{::Regexp.last_match(1)}  #{tag(path, code)}\n#{::Regexp.last_match(0)}" }
      else
        insert_in_indented_head(path, content, code)
      end
    end

    # Slim (`head`) and Haml (`%head`): append after the head's last child.
    def insert_in_indented_head(path, content, code)
      lines = content.lines
      head = lines.index { |line| line.match?(/\A[ \t]*%?head\b/) }
      return unless head

      last = last_child(lines, head)
      lines[last] = "#{lines[last].chomp}\n" # a head that ends the file without a newline
      lines.insert(last + 1, "#{child_indent(lines, head, last)}#{tag(path, code)}\n")
      lines.join
    end

    # Index of the last non-blank line indented under lines[head] (head itself if none).
    def last_child(lines, head)
      children = lines.drop(head + 1).take_while { |line| line.strip.empty? || indent(line) > indent(lines[head]) }
      last_filled = children.rindex { |line| !line.strip.empty? }
      last_filled ? head + 1 + last_filled : head
    end

    def child_indent(lines, head, last)
      first = lines[(head + 1)..last].find { |line| !line.strip.empty? }
      first ? first[/\A[ \t]*/] : "#{lines[head][/\A[ \t]*/]}  "
    end

    def indent(line)
      line[/\A[ \t]*/].size
    end
  end
end
