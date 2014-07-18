module RoadForest
  module Authorization
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
  end
end
