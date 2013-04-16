class MyServices < RoadForest::ServiceHost
  attr_accessor :app
end

app = RoadForest::build_app do |app|
  app.services = MyServices.new
  app.services.app = ResolutionApp.new

  app.routes do
    add  :root,              [],                       bundle_model(Resources::ReadOnly,  Models::Navigation)
    add  :needs,             ["needs"],                bundle_model(Resources::List,      Models::NeedList)
    add  :resolved_needs,    ["resolved-needs"],       bundle_model(Resources::List,      Models::ResolvedNeedList)
    add  :unresolved_needs,  ["unresolved-needs"],     bundle_model(Resources::List,      Models::UnresolvedNeedList)
    add  :need,              ["needs",'*'],            bundle_model(Resources::LeafItem,  Models::Need)
    add  :status,            ["provisioning-status"],  bundle_model(Resources::LeafItem,  Models::Status)
  end
end


app.run

module LogicalConstruct
  class WebmachineResolver
    class ResolutionApp

      attr_accessor :status, :needs, :provisioning_directory
      attr_reader :last_unresolved_poll

      def initialize
        @needs = []
        @status = "UNKNOWN"
        @last_unresolved_poll = Time.now
      end

      def mark_unresolved_poll
        @last_unresolved_poll = Time.now
      end

      def add_need(path, signature)
        need = Need.new
        need.root_directory = @provisioning_directory
        need.path = path
        need.signature = signature
        @needs << need
        need
      end

      class Need
        include ResolutionProtocol

        attr_accessor :resolved, :path, :signature, :root_directory

        def initialize
          @resolved = false
        end

        def receive_file(tmp_path)
          check_digest(signature, tmp_path, path) unless signature.empty?
          FileUtils::cp(tmp_path, File::join(@root_directory, path))
          @resolved = true
          return true
        ensure
          FileUtils::rm_f(tmp_path)
        end
      end
    end

    module Vocabulary
      class LC < RDF::Vocabulary("http://lrdesign.com/logical-construct")
        property :Need
        property :path
        property :resolved
        property :file
        property :signature
      end
    end

    module Models
      class Need < RoadForest::Model
        def find_data(params)
          need_path = params.remainder.join("/")
          services.app.needs.find{|need| need.path == need_path}
        end

        def retreive(params)
          need = data_for(params)
          graph = graph_for(:need, params)
          graph[[:rdfs, "type"]] = [:lc, "Need"]
          graph[[:lc, "path"]] = need.path
          graph[[:lc, "signature"]] = need.signature
          graph[[:lc, "resolved"]] = need.resolved
          graph[[:lc, "file"]] = services.router.path_for(:files, '*' => need.path)
          graph
        end

        def update(params, graph)
          need = data_for(params)
          if need.nil?
            path = graph[[:lc, "path"]]
            signature = graph[[:lc, "signature"]]
            ResolutionApp.add_need(path, signature)
          else
            #???
          end
        end

        def delete(params)
          #??? Not allowed?
        end
      end
    end

    module Resources
      class Navigation < ResolverResource
        def html_template; "navigation.html"; end
      end

      class Need < ResolverResource
        include FormParsing

        def allowed_methods
          %w{GET HEAD POST}
        end

        def need_path
          @need_path ||= request.path_tokens.join("/")
        end

        def resource_exists?
          resolution_app.needs.find{|need| need.path == need_path}
        end

        def build_representation
          rep = super
          rep[:need] = resolution_app.needs.find{|need| need.path == need_path}
          rep
        end

        def handle_form(data)
          representation[:need].receive_file(data["file"].last.path)
        end

        def html_template; "need.html"; end
      end

      class NeedList < ResolverResource
        include FormParsing

        def allowed_methods
          %w{GET HEAD PUT}
        end

        def handle_form(data)
          if resolution_app.needs.any?{|need| need.path == data.fetch("path")}
            return 409
          end
          resolution_app.add_need(data.fetch("path"), data.fetch("signature"))
        end

        def filtered_needs
          resolution_app.needs
        end

        def build_representation
          rep = super
          rep[:needs] = filtered_needs
          rep[:filter] = request.path_info[:only]
          rep
        end

        def html_template; "need-list.html"; end
      end

      class ResolvedNeedList < NeedList
        def filtered_needs
          resolution_app.needs.find_all{|need| need.resolved}
        end
      end

      class UnresolvedNeedList < NeedList
        def filtered_needs
          resolution_app.mark_unresolved_poll
          resolution_app.needs.find_all{|need| !need.resolved}
        end
      end

      class Status < ResolverResource
        include FormParsing

        def allowed_methods
          %w{GET HEAD PUT POST}
        end

        def handle_form(data)
          resolution_app.status = data.fetch("status")
        end

        def html_template; "status.html"; end

        def build_representation
          rep = super
          rep[:status] = resolution_app.status
          rep[:last_unresolved_poll] = resolution_app.last_unresolved_poll
          rep[:server_time] = Time.now
          rep[:time_format] = "%Y-%m-%d %H:%M:%S.%L UTC"
          rep
        end
      end
    end
  end
end
