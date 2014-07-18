require 'roadforest/authorization/auth-entity'
module RoadForest
  module Authorization
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
  end
end
