require 'roadforest-client'
require 'roadforest-server'

require 'rdf/vocab/skos'

describe RoadForest::RemoteHost, "#forbidden?" do
  module Vocabulary
    class LC < ::RDF::Vocabulary("http://lrdesign.com/vocabularies/logical-construct#")
      property :name
    end
  end

  let :root_interface_class do
    Class.new(RoadForest::Interface::RDF) do
      def exists?; true; end

      def required_grants(method)
        []
      end

      def fill_graph(graph)
        graph[:lc, "next"] = path_for(:restricted)
      end
    end
  end

  let :authz_interface_class do
    Class.new(RoadForest::Interface::RDF) do
      def exists?; true; end

      def required_grants(method)
        services.authz.build_grants do |builder|
          (1..5).each do |idx|
            build.add(:extra_random_grant, :idx => idx)
          end

          builder.add(:clearance_level_one) #buried on purpose

          builder.add(:doesnt_need_params, :x => 1, :y => 3)
          (6..10).each do |idx|
            build.add(:extra_random_grant, :idx => idx)
          end
        end
      end

      def fill_graph(graph)
      end
    end
  end

  let :policy_class do
    Class.new(RoadForest::Authorization::Policy) do
      def grants_for(entity)
        case entity.username
        when "roy", "gregg"
          build_grants do |builder|
            builder.add(:clearance_level_one)
          end
        else
          []
        end
      end
    end
  end

  let :services do
    require 'logger'

    RoadForest::Application::ServicesHost.new.tap do |host|
      host.router.add :root      , []                  , :read_only, root_interface_class
      host.router.add :restricted, ["auth_only"]       , :read_only, authz_interface_class
      host.router.add :perm      , ["perm",:grant]     , :read_only, RoadForest::Utility::Grant
      host.router.add :perm_list , ["perm_list",:grant], :read_only, RoadForest::Utility::GrantList

      host.root_url = "http://localhost:8778"
      host.authz.authenticator.add_account("roy",     "secret",  "token")
      host.authz.authenticator.add_account("gregg",   "secret",  "token")
      host.authz.authenticator.add_account("david",   "secret",  "token")
      host.authz.authenticator.add_account("jeremy",  "secret",  "token")

      host.authz.policy = policy_class.new
      host.authz.policy.grants_holder = host.authz.grants
    end
  end

  let :server do
    require 'roadforest/type-handlers/jsonld'
    RoadForest::TestSupport::RemoteHost.new(services).tap do |server|
      #server.trace = true
#      server.graph_transfer.type_handling = RoadForest::ContentHandling::Engine.new.tap do |engine|
#        engine.add RoadForest::TypeHandlers::JSONLD.new, "application/ld+json"
#      end
    end
  end

  let :content_type do
    "application/ld+json"
  end

  def dump_trace
    tracing = true
    tracing = false
    if tracing
      RoadForest::TestSupport::FSM.dump_trace
    end
  end

  before :each do
    RoadForest::TestSupport::FSM.trace_on
  end

  describe "on a page that links to a resource authorized by many different permissions" do
    describe "for authorized user" do
      before :each do
        server.add_credentials("roy", "secret")
      end

      it "should include an authorizedBy statement" do
        resource = nil
        authzs = nil
        server.getting do |graph|
          resource = graph[[:lc, "next"]]
          authzs = graph.access_manager.query(:predicate => RoadForest::Graph::Af.authorizedBy).to_a
        end
        resource.should_not be_nil
        authzs.should_not be_empty
      end

      it "should return 200 for auth'd perm"
      it "should return 401 for nonesense perm"
      it "should return false for forbidden?(resource)"
      it "should take no more than 3 requests to determine forbidden?"
    end
    describe "for unauthorized user" do
      it "should return 401 for auth'd perm"
      it "should return true for forbidden?(resource)"
      it "should take no more than 3 requests to determine forbidden?"
    end
  end
end
