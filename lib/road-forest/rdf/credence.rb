module RoadForest::RDF
  module Credence
    def self.policies
      @policies ||= {
        :authoritative => AnyAuthoritative.new,
        :any => Any.new,
        :must_authoritative => MustBeAuthoritative.new
      }
    end

    def self.policy(name)
      if block_given?
        policies[name] ||= yield
      else
        begin
          policies.fetch(name)
        rescue KeyError
          raise "No Credence policy for #{name.inspect} (available named policies are #{policies.keys.inspect})"
        end
      end
    end

    #If there are any results for the subject context, they're good
    class AnyAuthoritative
      def credible(subject, results)
        results.for_context(subject)
      end
    end

    class Any
      def credible(subject, results)
        results.for_context(results.contexts.last)
      end
    end

    #Unless we have results for the subject context, nothing is valid
    class MustBeAuthoritative
      def credible(subject, results)
        if results.for_context(subject).nil?
          raise NotCredible
        else
          nil
        end
      end
    end
  end
end
