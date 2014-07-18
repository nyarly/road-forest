require 'roadforest/authorization/grant-builder'
module RoadForest
  module Authorization
    # Caches the obfuscated tokens used to identify permission grants
    class GrantsHolder
      def initialize(salt, hash_function)
        digester = OpenSSL::HMAC.new(salt, hash_function)
        @conceal = true
        @grants_cache = Hash.new do |h, k| #XXX potential resource exhaustion here - only accumulate auth'd results
          if conceal
            digester.reset
            digester << k.inspect
            h[k] = digester.hexdigest
          else
            h[k] = k.inspect
          end
        end
      end
      attr_accessor :conceal

      def get(key)
        @grants_cache[key]
      end
      alias [] get

      def build_grants
        builder = GrantBuilder.new(self)
        yield builder
        return builder.list
      end
    end
  end
end
