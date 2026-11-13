# frozen_string_literal: true

module RspackRails
  # Minimal semver range matching for package.json "engines" fields.
  # Supports `||`, space-separated comparators, ^, ~, >=, <=, >, <, = and
  # partial versions (20, 20.x).
  module NodeVersion
    COMPARATOR = /\A(\^|~|>=|<=|>|<|=)?v?(\d+)(?:\.(\d+|x|\*))?(?:\.(\d+|x|\*))?\z/

    OPERATORS = {
      "^" => ->(cmp, current, target) { cmp >= 0 && current[0] == target[0] },
      "~" => ->(cmp, current, target) { cmp >= 0 && current[0..1] == target[0..1] },
      ">=" => ->(cmp, _, _) { cmp >= 0 },
      "<=" => ->(cmp, _, _) { cmp <= 0 },
      ">" => ->(cmp, _, _) { cmp.positive? },
      "<" => ->(cmp, _, _) { cmp.negative? }
    }.freeze

    Comparator = Struct.new(:operator, :parts) do
      def match?(current)
        target = parts + ([0] * (3 - parts.size))
        operation = OPERATORS[operator]
        return current.take(parts.size) == parts unless operation

        operation.call(current <=> target, current, target)
      end
    end

    module_function

    def parse(version)
      version.to_s.strip.match(/\Av?(\d+)\.(\d+)\.(\d+)/)&.captures&.map(&:to_i)
    end

    # true or false when the range can be read; nil when the version or any
    # part of the range is in a form this matcher does not support.
    def check(version, range)
      current = parse(version)
      sets = parse_range(range)
      return nil unless current && sets

      sets.any? { |comparators| comparators.all? { |comparator| comparator.match?(current) } }
    end

    def parse_range(range)
      sets = range.to_s.split("||").map { |set| set.strip.split(/\s+/).map { |c| parse_comparator(c) } }
      sets.flatten.all? ? sets : nil
    end

    def parse_comparator(text)
      match = text.match(COMPARATOR)
      return unless match

      parts = match.captures.drop(1).take_while { |part| part&.match?(/\A\d+\z/) }.map(&:to_i)
      Comparator.new(match[1], parts)
    end
  end
end
