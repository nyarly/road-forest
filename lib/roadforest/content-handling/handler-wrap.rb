module RoadForest
  module ContentHandling
    module Wrap
      class Wrapper
        def initialize(type, handler)
          @type = type
          @handler = handler
        end
        attr_reader :type, :handler

        def local_to_network(base_uri, network)
          @handler.local_to_network(base_uri, network)
        end
        alias from_graph local_to_network

        def network_to_local(base_uri, source)
          @handler.network_to_local(base_uri, source)
        end
        alias to_graph network_to_local
      end

      class Render < Wrapper
        def call(resource)
          @handler.render_for(resource)
        end

        def content_type_header
          @type.content_type_header
        end
      end

      class Parse < Wrapper
        def call(resource)
          @handler.parse_for(resource)
        end

        def add_child(resource)
          @handler.add_child_to(resource)
        end
      end
    end
  end
end
