require 'base64'
require 'roadforest/utility/class-registry'
module RoadForest
  module Authorization
    class AuthenticationChain
      class Scheme
        def self.registry_purpose; "authentication scheme"; end
        extend Utility::ClassRegistry::Registrar

        def self.register(name)
          registrar.registry.add(name, self.new)
        end

        def authenticated_entity(credentials, store)
          nil
        end
      end

      class Basic < Scheme
        register "Basic"

        def challenge(options)
          "Basic realm=\"#{options.fetch(:realm, "Roadforest App")}\""
        end

        def authenticated_entity(credentials, store)
          username, password = Base64.decode64(credentials).split(':',2)

          entity = store.by_username(username)
          entity.authenticate_by_password(password)
          entity
        end
      end

      def initialize(store)
        @store = store
      end
      attr_reader :store

      def handler_for(scheme)
        Scheme.get(scheme)
      rescue
        nil
      end

      def challenge(options)
        (Scheme.registry.names.map do |scheme_name|
          handler_for(scheme_name).challenge(options)
        end).join(", ")
      end

      def add_account(user,password,token)
        @store.add_account(user,password,token)
      end

      def authenticate(header)
        return nil if header.nil?
        scheme, credentials = header.split(/\s+/, 2)

        handler = handler_for(scheme)
        return nil if handler.nil?

        entity = handler.authenticated_entity(credentials, store)
        return nil if entity.nil?
        return nil unless entity.authenticated?
        return entity
      end
    end
  end
end
