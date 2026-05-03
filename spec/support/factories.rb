require "bigdecimal"

module Snoot
  module Spec
    module Factories
      def build_path(raw: "lib/foo.rb")
        Snoot::Path.new(raw: raw)
      end

      def build_location(path: build_path, line_start: 10, line_end: 20)
        Snoot::Location.new(path: path, line_start: line_start, line_end: line_end)
      end

      def build_smell_type(name: "FeatureEnvy")
        Snoot::SmellType.new(name: name)
      end

      def build_smell(smell_type: build_smell_type, location: build_location, message: "method envies another object")
        Snoot::Smell.new(smell_type: smell_type, location: location, message: message)
      end

      def build_complexity_hit(location: build_location, method_name: "Foo#bar", score: BigDecimal("12.5"))
        Snoot::ComplexityHit.new(location: location, method_name: method_name, score: score)
      end

      def build_duplication_cluster(signature: "abc123", locations: Set[build_location])
        Snoot::DuplicationCluster.new(signature: signature, locations: locations)
      end
    end
  end
end
