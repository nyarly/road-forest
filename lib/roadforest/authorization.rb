require 'base64'
require 'openssl'
require 'roadforest'
require 'roadforest/utility/class-registry'

module RoadForest
  module Authorization
    class GrantBuilder
      def initialize(salt, cache)
        @salt = salt
        @cache = cache
        @list = []
      end
      attr_reader :list

      def add(name, params=nil)
        canonical =
          if params.nil?
            [@salt, name]
          else
            [@salt, name, params.keys.sort.map do |key|
              [key, params[key]]
            end]
          end
        @list << @cache[canonical]
      end
    end

    class GrantsHolder
      def initialize(salt, hash_function)
        @salt = salt

        digester = OpenSSL::Digest.new(hash_function)
        @grants_cache = Hash.new do |h, k| #XXX potential resource exhaustion here - only accumulate auth'd results
          digester.reset
          h[k] = digester.digest(h.inspect)
        end
      end

      def get(key)
        @grants_cache[key]
      end
      alias [] get

      def build_grants
        builder = GrantBuilder.new(@salt, self)
        yield builder
        return builder.list
      end
    end

    class Manager
      attr_accessor :authenticator
      attr_accessor :policy
      attr_reader :grants

      HASH_FUNCTION = "SHA256".freeze

      def initialize(salt = nil, authenticator = nil, policy = nil)
        @grants = GrantsHolder.new(salt || "roadforest-insecure", HASH_FUNCTION)

        @authenticator = authenticator || AuthenticationChain.new(DefaultAuthenticationStore.new)
        @policy = policy || AuthorizationPolicy.new
        @policy.grants_holder = @grants
      end

      def build_grants(&block)
        @grants.build_grants(&block)
      end

      def challenge(options)
        @authenticator.challenge(options)
      end

      # @returns [:public|:granted|:refused]
      #
      # :public means the request doesn't need authorization
      # :granted means that it does need authz but the credentials passed are
      #   allowed to access the resource
      # :refused means that the credentials passed are not allowed to access
      #   the resource
      #
      # TODO: Resource needs to add s-maxage=0 for :granted requests or public
      # for :public requests to the CacheControl header
      def authorization(header, required_grants)
        entity = authenticator.authenticate(header)

        return :refused if entity.nil?

        available_grants = policy.grants_for(entity)

        if required_grants.any?{|required| available_grants.include?(required)}
          return :granted
        else
          return :refused
        end
      end
    end

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

    class AuthEntity
      def initialize
        @authenticated = false
      end
      attr_accessor :username, :password, :token

      def authenticated?
        !!@authenticated
      end

      def authenticate_by_password(password)
        @authenticated = (!password.nil? and password == @password)
      end

      def authenticate_by_token(token)
        @authenticated = (!token.nil? and token == @token)
      end

      def authenticate!
        @authenticated = true
      end
    end

    class DefaultAuthenticationStore
      def initialize
        @accounts = []
      end

      def build_entity(account)
        return nil if account.nil?
        AuthEntity.new.tap do |entity|
          entity.username = account[0]
          entity.password = account[1]
          entity.token = account[2]
        end
      end

      def add_account(user, password, token)
        @accounts << [user, password, token]
      end

      def by_username(username)
        account = @accounts.find{|account| account[0] == username }
        build_entity(account)
      end

      def by_token(token)
        account = @accounts.find{|account| account[2] == token }
        build_entity(account)
      end
    end

    class AuthorizationPolicy
      attr_accessor :grants_holder

      def build_grants(&block)
        grants_holder.build_grants(&block)
      end

      def grants_for(entity)
        build_grants do |builder|
          builder.add(:admin)
        end
      end
    end
  end
end
