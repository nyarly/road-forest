require 'base64'
require 'addressable/uri'

module RoadForest
  module HTTP
    #Manages user credentials for HTTP Basic auth
    class Keychain
      class Credentials < Struct.new(:user, :secret)
        def header_value
          "Basic #{Base64.strict_encode64("#{user}:#{secret}")}"
        end
      end

      def initialize
        @realm_for_url = {}
        @with_realm = {}
      end

      def add(url, user, secret, realm=nil)
        creds = Credentials.new(user, secret)
        add_credentials(url, creds, realm || :default)
      end

      def add_credentials(url, creds, realm)
        if url.to_s[-1] != "/"
          url << "/"
        end
        @realm_for_url[url.to_s] = realm

        url = Addressable::URI.parse(url)
        url.path = "/"
        @with_realm[[url.to_s,realm]] = creds
      end

      BASIC_SCHEME = /basic\s+realm=(?<q>['"])(?<realm>(?:(?!['"]).)*)\k<q>/i

      def challenge_response(url, challenge)
        if (match = BASIC_SCHEME.match(challenge)).nil?
          return nil
        end
        realm = match[:realm]

        response(url, realm)
      end

      def response(url, realm)
        lookup_url = Addressable::URI.parse(url)
        lookup_url.path = "/"
        creds = @with_realm[[lookup_url.to_s,realm]]
        if creds.nil? and not realm.nil?
          creds = missing_credentials(url, realm)
          unless creds.nil?
            add_credentials(url, creds, realm)
          end
        end

        return nil if creds.nil?

        return creds.header_value
      end

      def missing_credentials(url, realm)
        nil
      end

      def preemptive_response(url)
        url = Addressable::URI.parse(url)

        while (realm = @realm_for_url[url.to_s]).nil?
          new_url = url.join("..")
          break if new_url == url
          url = new_url
        end

        return response(url, realm)
      end
    end
  end
end
