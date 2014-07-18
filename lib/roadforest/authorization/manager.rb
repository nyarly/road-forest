require 'roadforest/authorization/authentication-chain'
require 'roadforest/authorization/grants-holder'
require 'roadforest/authorization/default-authentication-store'
require 'roadforest/authorization/policy'

module RoadForest
  module Authorization
    # The root of the RoadForest authorization scheme.

    # Resources describe a set of permissions that are allowed to access them,
    # on a per-method case.
    #
    # An overall Policy object provides permission grants to authenticated
    # entities (typically users, but could be e.g. applications acting on their
    # behalf)
    #
    # The ultimate grant/refuse decision comes down to: is there a shared
    # permission in the list required by the resource and those granted to the
    # entity.
    #
    # Permissions have a name and an optional set of parameters, and can be
    # referred to as such within the application on the server. They're stored
    # as digests of those names, which should be safe to communicate to the
    # user application, which can make interaction decisions based on the
    # permissions presented.
    #
    # The default ServicesHost exposes a Manager as #authz
    class Manager
      attr_accessor :authenticator
      attr_accessor :policy
      attr_reader :grants

      HASH_FUNCTION = "SHA256".freeze

      def initialize(salt = nil, authenticator = nil, policy = nil)
        #XXX consider launch-time randomized salt
        @grants = GrantsHolder.new(salt || "roadforest-insecure", HASH_FUNCTION)

        @authenticator = authenticator || AuthenticationChain.new(DefaultAuthenticationStore.new)
        @policy = policy || Policy.new
        @policy.grants_holder = @grants
      end

      def cleartext_grants!
        @grants.conceal = false
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
  end
end
