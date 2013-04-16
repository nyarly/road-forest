require 'webmachine'
require 'logical-construct/webmachine-linking'
require 'mattock/template-host'
require 'logical-construct/resolving-task'
require 'multipart_parser/reader'
require 'fileutils'

module LogicalConstruct
  class WebmachineResolver
    def initialize
      @valise = nil
      @model = ResolutionApp.new
    end

    attr_accessor :valise, :model

    def build_app
      templates_valise = @valise.templates("templates/webmachine-resolver")

      web_app = Webmachine::Application.new do |app|
        app.routes do
          add [], Resources::Navigation
          add ["needs"], Resources::NeedList
          add ["resolved-needs"], Resources::ResolvedNeedList
          add ["unresolved-needs"], Resources::UnresolvedNeedList
          add ["needs", '*'], Resources::Need
          add ["provisioning-status"], Resources::Status
        end

        original_resource_creator = app.dispatcher.resource_creator
        url_provider = Webmachine::Linking::UrlProvider.new(app.dispatcher.routes)

        app.dispatcher.resource_creator = proc do |route, request, response|
          resource = original_resource_creator[route,request,response]
          resource.url_provider = url_provider
          resource.resolution_app = model
          resource.valise = templates_valise
          resource
        end
      end
      return web_app
    end

    def start
      build_app.run
    end

    class ResolverResource < ::Webmachine::Resource
      include Webmachine::Linking::Resource::LinkHelpers

      attr_accessor :resolution_app, :valise

      def build_representation
        rep = Representation.new
        rep.url_provider = url_provider
        rep.valise = valise
        rep
      end

      def representation
        @representation ||= build_representation
      end

      def to_html
        representation.render("main-layout.html") do |locals|
          locals[:content] = representation.render(html_template)
        end
      end
    end

    module Resources
    end

    class Representation
      include Mattock::TemplateHost
      include Webmachine::Linking::Resource::LinkHelpers
      include Resources

      alias template_render render

      def initialize
        @variables = Hash.new("")
      end

      def [](field)
        @variables[field.to_s]
      end

      def []=(field, value)
        @variables[field.to_s]=value
      end

      def render(template)
        template_render(template) do |locals|
          locals.merge!(@variables)
          yield locals if block_given?
        end
      end
    end

    module FormParsing
      def content_types_accepted
        [
          ["application/x-www-form-urlencoded", :handle_url_encoded_form],
          ["multipart/form-data", :handle_multipart_form]
        ]
      end

      def process_post
        content_type = Webmachine::MediaType.parse(request.content_type)
        if content_type.match?("application/x-www-form-urlencoded")
          handle_url_encoded_form
        elsif content_type.match?("multipart/form-data")
          handle_multipart_form
        else
          false
        end
      end

      def parse_url_encoded_form
        Hash[URI::decode_www_form(request.body)]
      end

      def parse_multipart_form
        form_data = {}
        reader = multipart_reader(request.content_type, form_data)

        request.body.each do |chunk|
          reader.write(chunk)
        end

        return form_data
      end

      def multipart_reader(content_type, form_data)
        content_type = Webmachine::MediaType.parse(content_type)
        reader = MultipartParser::Reader.new(content_type.params["boundary"])
        reader.on_error do |message|
          raise message
        end

        reader.on_part do |part|
          case part.mime
          when nil
            form_data[part.name] = ""
            part.on_data do |data|
              form_data[part.name] << data
            end
          else
            temp_file = Tempfile.new(part.filename)

            form_data[part.name] = [part, temp_file]

            part.on_data do |data|
              temp_file.write(data)
            end

            part.on_end do
              temp_file.close
            end
          end
        end

        return reader
      end

      def handle_url_encoded_form
        handle_form(parse_url_encoded_form)
      end

      def handle_multipart_form
        handle_form(parse_multipart_form)
      end
    end

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
