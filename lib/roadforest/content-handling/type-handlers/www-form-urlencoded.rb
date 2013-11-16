require 'roadforest/content-handling/type-handler'
require 'uri'

module RoadForest
  module MediaType
    module Handlers
      #application/x-www-form-urlencoded
      class WWWFormEncoded < Handler
        def local_to_network(base_url, list)
          URI::encode_www_form(enum)
        end

        def network_to_local(base_url, source)
          URI::decode_www_form(source)
        end
      end
    end
  end
end
