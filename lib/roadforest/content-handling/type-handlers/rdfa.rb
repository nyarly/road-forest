require 'rdf/rdfa' #XXX Otherwise json-ld grabs RDFa documents. Awaiting fix upstream
require 'roadforest/content-handling/type-handlers/rdf-handler'
module RoadForest
  module MediaType
    module Handlers
      class RESTfulRDFaWriter < ::RDF::RDFa::Writer
        HAML = ::RDF::RDFa::Writer::BASE_HAML.merge(:property_values => %q{
          - objects.each do |object|
            /
              = object.inspect
          %div.property
            %span.label
              = get_predicate_name(predicate)
            %ul
              - objects.each do |object|
                - if res = yield(object, :inlist => inlist, :element => :li)
                  != res
                - elsif object.node?
                  %li{:property => get_curie(predicate), :resource => get_curie(object), :inlist => inlist}= get_curie(object)
                - elsif object.uri?
                  %li
                    %a{:property => get_curie(predicate), :href => object.to_s, :inlist => inlist}= object.to_s
                - elsif object.datatype == RDF.XMLLiteral
                  %li{:property => get_curie(predicate), :lang => get_lang(object), :datatype => get_curie(object.datatype), :inlist => inlist}<!= get_value(object)
                - else
                  %li{:property => get_curie(predicate), :content => get_content(object), :lang => get_lang(object), :datatype => get_dt_curie(object), :inlist => inlist}= escape_entities(get_value(object))
        })

        def initialize(output = $stdout, options = nil, &block)
          options ||= {}
          options = {:haml => HAML}
          super(output, options, &block)
        end


        # Write a predicate with one or more values.
        #
        # Values may be a combination of Literal and Resource (Node or URI).
        # @param [RDF::Resource] predicate
        #   Predicate to serialize
        # @param [Array<RDF::Resource>] objects
        #   Objects to serialize
        # @return [String]
        def predicate(predicate, objects, options = nil)
          add_debug {"predicate: #{predicate.inspect}, objects: #{objects}"}

          return if objects.to_a.empty?

          add_debug {"predicate: #{get_curie(predicate)}"}
          render_property(predicate, objects, options || {}) do |o, opts|
            # Yields each object, for potential recursive definition.
            # If nil is returned, a leaf is produced
            opts = {:rel => get_curie(predicate), :element => (:li if objects.length > 1)}.merge(opts||{})

            if !is_done?(o) && @subjects.include?(o)
              depth {subject(o, opts)}
            end
          end
        end


        # Render a single- or multi-valued predicate using
        # `haml_template[:property_value]` or
        # `haml_template[:property_values]`. Yields each object for optional
        # rendering. The block should only render for recursive subject
        # definitions (i.e., where the object is also a subject and is rendered
        # underneath the first referencing subject).
        #
        # If a multi-valued property definition is not found within the template, the writer will use the single-valued property definition multiple times.
        #
        # @param [Array<RDF::Resource>] predicate
        #   Predicate to render.
        # @param [Array<RDF::Resource>] objects
        #   List of objects to render. If the list contains only a single element, the :property_value template will be used. Otherwise, the :property_values template is used.
        # @param [Hash{Symbol => Object}] options Rendering options passed to Haml render.
        # @option options [String] haml (haml_template[:property_value], haml_template[:property_values])
        #   Haml template to render. Otherwise, uses `haml_template[:property_value] or haml_template[:property_values]`
        #   depending on the cardinality of objects.
        # @yield [object]
        #   Yields object.
        # @yieldparam [RDF::Resource] object
        # @yieldreturn [String, nil]
        #   The block should only return a string for recursive object definitions.
        # @return String
        #   The rendered document is returned as a string
        def render_property(predicate, objects, options = {}, &block)
          add_debug {"render_property(#{predicate}): #{objects.inspect}"}
          # If there are multiple objects, and no :property_values is defined, call recursively with
          # each object

          template = options[:haml]
          template ||= objects.length > 1 ? haml_template[:property_values] : haml_template[:property_value]

          # Separate out the objects which are lists and render separately
          list_objects = objects.select {|o| o != ::RDF.nil && ::RDF::List.new(o, @graph).valid?}
          unless list_objects.empty?
            # Render non-list objects
            add_debug {"properties with lists: non-lists: #{objects - list_objects} lists: #{list_objects}"}
            nl = render_property(predicate, objects - list_objects, options, &block) unless objects == list_objects
            return nl.to_s + list_objects.map do |object|
              # Render each list as multiple properties and set :inlist to true
              list = ::RDF::List.new(object, @graph)
              list.each_statement {|st| subject_done(st.subject)}

              add_debug {"list: #{list.inspect} #{list.to_a}"}
              render_property(predicate, list.to_a, options.merge(:inlist => "true"), &block)
            end.join(" ")
          end

          if objects.length > 1 && template.nil?
            # Uf there is no property_values template, render each property using property_value template
            objects.map do |object|
              render_property(predicate, [object], options, &block)
            end.join(" ")
          else
            raise ::RDF::WriterError, "Missing property template" if template.nil?

            template = options[:haml] || (
              objects.to_a.length > 1 &&
              haml_template.has_key?(:property_values) ?
              :property_values :
              :property_value)
              options = {
                :objects    => objects,
                :object     => objects.first,
                :predicate  => predicate,
                :property   => get_curie(predicate),
                :rel        => get_curie(predicate),
                :inlist     => nil,
              }.merge(options)
              hamlify(template, options) do |object, options|
                yield(object, options) if block_given?
              end
          end
        end

      end

      #text/html;q=1;rdfa
      #image/svg+xml;q=1;rdfa
      #application/xhtml+xml;q=1;rdfa
      #text/html
      #image/svg+xml
      #application/xhtml+xml
      class RDFa < RDFHandler
        include RDF::Normalization

        def local_to_network(base_uri, rdf)
          raise "Invalid base uri: #{base_uri}" if base_uri.nil?
          prefixes = relevant_prefixes_for_graph(rdf)
          prefixes.keys.each do |prefix|
            prefixes[prefix.to_sym] = prefixes[prefix]
          end
          #::RDF::RDFa.debug = true
          RESTfulRDFaWriter.buffer(:base_uri => base_uri.to_s,
                                   :prefixes => prefixes) do |writer|
            rdf.each_statement do |statement|
              writer << statement
            end
                                   end
        end

        def network_to_local(base_uri, source)
          raise "Invalid base uri: #{base_uri.inspect}" if base_uri.nil?
          graph = ::RDF::Graph.new
          reader = ::RDF::RDFa::Reader.new(source.to_s, :base_uri => base_uri.to_s)
          reader.each_statement do |statement|
            graph.insert(statement)
          end
          graph
        end
      end
    end
  end
end
