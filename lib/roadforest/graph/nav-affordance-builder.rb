require 'roadforest/graph'

module RoadForest
  module Graph
    class NavAffordanceBuilder
      def initialize(focus, path_provider)
        @focus, @path_provider = focus, path_provider
      end
      attr_reader :path_provider, :focus

      def to(name, params=nil)
        route = path_provider.route_for_name(name)

        pattern = iri_template(route, params)

        node = ::RDF::Node.new
        tmpl = ::RDF::Node.new
        focus << [ node, ::RDF.type, Af.Navigate ]
        focus << [ node, Af.target, tmpl ]
        focus << [ tmpl, Af.pattern, pattern ]
      end

      def iri_template(route, params)
        klass = route.interface_class
        return if klass.nil?

        variables = klass.path_params

        params ||= {}
        params = params.dup

        variables -= params.keys

        path_spec = route.resolve_path_spec(params)

        path = path_provider.services.canonical_host.to_s.sub(%r{/$}, '') +
          path_spec.map do |segment|
          case segment
          when Symbol
            variables.delete(segment)
            "{/#{segment}}"
          when '*'
            "{/extra*}"
          else
            "/" + segment.to_s
          end
          end.join("")

          unless params.empty?
            path += "?" + params.map do |key, value|
              [key, value].join("=")
            end.join("&")
          end

          unless variables.empty?
            path += "{?#{variables.join(",")}}"
          end
      end
    end
  end

end
