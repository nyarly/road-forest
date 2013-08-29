require 'roadforest/test-support/trace-formatter'
require 'webmachine/headers'
require 'webmachine/request'
require 'webmachine/response'
require 'webmachine/decision/flow'
module RoadForest
  module TestSupport
    class DispatcherFacade < BasicObject
      def initialize(dispatcher)
        @dispatcher = dispatcher
      end

      def method_missing(method, *args, &block)
        @dispatcher.__send__(method, *args, &block)
      end

      def dispatch(request, response)
        if resource = @dispatcher.find_resource(request, response)
          FSM.new(resource, request, response).run
        else
          ::Webmachine.render_error(404, request, response)
        end
      end
    end

    class FSM < ::Webmachine::Decision::FSM
      def self.trace_on
        unless ancestors.include? Webmachine::Trace::FSM
          include Webmachine::Trace::FSM
        end
        Webmachine::Trace.trace_store = :memory
      end

      def self.dump_trace
        puts trace_dump
      end

      def self.trace_dump
        Webmachine::Trace.traces.map do |trace|
          TraceFormatter.new(Webmachine::Trace.fetch(trace))
        end.join("\n")
      end

      #Um, actually *don't* handle exceptions
      def handle_exceptions
        yield.tap do |result|
          #p result #ok
        end
      end

      def initialize_tracing
        return if self.class.ancestors.include? Webmachine::Trace::FSM
        super
      end

      def run
        state = Webmachine::Decision::Flow::START
        trace_request(request)
        loop do
          trace_decision(state)
          result = handle_exceptions { send(state) }
          case result
          when Fixnum # Response code
            respond(result)
            break
          when Symbol # Next state
            state = result
          else # You bwoke it
            raise InvalidResource, t('fsm_broke', :state => state, :result => result.inspect)
          end
        end
      ensure
        trace_response(response)
      end
    end
  end
end
