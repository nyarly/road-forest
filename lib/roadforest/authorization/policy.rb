module RoadForest
  module Authorization
    # Responsible to assigning particular permission grants to entities. There
    # should be one subclass of Policy per application, ideally.
    class Policy
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
