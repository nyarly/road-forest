require 'roadforest/content-handling/type-handlers/rdf-handler'

module RoadForest
  module MediaType
    module Handlers
      #application/x-www-form-urlencoded
      class RDFPost < RDFHandler

        #c.f. http://www.lsrn.org/semweb/rdfpost.html
        class Reader < ::RDF::Reader
          module St
            class State
              def initialize(reader)
                @reader = reader
                @accept_hash = cleanup(accept_list)
              end

              def cleanup(accept_list)
                hash = Hash.new{ accept_list[nil] }
                accept_list.each_key do |key|
                  next if key.nil?
                  hash[key.to_s] = accept_list[key]
                end
                hash
              end

              def blank_node(name)
                ::RDF::Node.new(name)
              end

              def base_uri
                ::RDF::URI.intern(@reader.options[:base_uri])
              end

              def uri(string)
                base_uri.join(string)
              end

              def prefix_uri(name)
                ::RDF::URI.intern(@reader.options[:prefixes][name])
              end

              def clear_subject
                @reader.subject = nil
                @reader.subject_prefix = nil
              end

              def clear_predicate
                @reader.predicate = nil
                @reader.predicate_prefix = nil
              end

              def clear_object
                @reader.object = nil
                @reader.object_prefix = nil
              end

              def consume_next(name)
                consume
                next_state(name)
              end

              def consume
                @reader.consume_pair
              end

              def triple_complete
                @reader.new_triple = true
              end

              def next_state(name)
                @reader.current_state = @reader.states.fetch(name)
              end

              def accept(key, value)
                #puts "#{[self.class.to_s.sub(/.*:/,''), key,
                #value.sub(/\s*\Z/,'')].inspect}"
                @accept_hash[key][value.sub(/\s*\Z/,'')]
              end
            end

            class RDF < State
              def accept_list
                { rdf: proc{|v| consume_next(:def_ns_decl) },
                  nil => proc{ consume } }
              end
            end

            class DefNsDecl < State
              def accept_list
                { v: proc {|v| consume_next(:ns_decl); @reader.options[:prefixes][nil] = v},
                  nil => proc{|v| next_state(:ns_decl)}}
              end
            end

            class NsDecl < State
              def accept_list
                { n: proc{|v| consume_next(:ns_decl_suffix); @reader.namespace_prefix = v},
                  nil => proc{|v| next_state(:subject)}}
              end
            end

            class NsDeclSuffix < State
              def accept_list
                { v: proc{|v| consume_next(:ns_decl); @reader.options[:prefixes][@reader.namespace_prefix] = v},
                  nil => proc{ next_state(:ns_decl)}}
              end
            end

            class SkipToSubject < State
              def accept_list
                next_is_subject = proc{ next_state(:subject); clear_subject; clear_predicate; clear_object }
                {
                  sb: next_is_subject,
                  su: next_is_subject,
                  sv: next_is_subject,
                  sn: next_is_subject,
                  nil => proc{ consume }
                }
              end
            end

            class SkipToSubjectOrPred < SkipToSubject
              def accept_list
                next_is_pred = proc{ next_state(:predicate); clear_predicate; clear_object }
                super.merge( pu: next_is_pred, pv: next_is_pred, pn: next_is_pred )
              end
            end

            class Subject < State
              def accept_list
                {
                  sb: proc{|v| consume_next(:predicate); @reader.subject = blank_node(v)},
                  su: proc{|v| consume_next(:predicate); @reader.subject = uri(v)},
                  sv: proc{|v| consume_next(:predicate); @reader.subject = prefix_url(nil) / v},
                  sn: proc{|v| consume_next(:subject_suffix); @reader.subject_prefix = prefix_uri(v)},
                  nil => proc{ consume }
                }
              end
            end

            class SubjectSuffix < State
              def accept_list
                {
                  sv: proc{|v| consume_next(:predicate); @reader.subject = @reader.subject_prefix/v},
                  nil => proc{ next_state(:skip_to_subject)}
                }
              end
            end

            class Predicate < State
              def accept_list
                {
                  pu: proc {|v| @reader.predicate = uri(v); consume_next(:object)},
                  pv: proc {|v| @reader.predicate = prefix_uri(nil) / v; consume_next(:object)},
                  pn: proc {|v| @reader.predicate_prefix = prefix_uri(v); consume_next(:predicate_suffix)},
                  nil => proc { next_state(:skip_to_subject)}
                }
              end
            end

            class PredicateSuffix < State
              def accept_list
                {
                  pv: proc{|v| consume_next(:object); @reader.predicate = @reader.predicate_prefix/v},
                  nil => proc{ next_state(:skip_to_subject)}
                }
              end
            end

            class Object < State
              def accept_list
                {
                  ob: proc{|v| consume; triple_complete; @reader.object = blank_node(v)},
                  ou: proc{|v| consume; triple_complete; @reader.object = uri(v)},
                  ov: proc{|v| consume; triple_complete; @reader.object = prefix_uri(nil) / v},
                  on: proc{|v| consume_next(:object_suffix); @reader.object_prefix = prefix_uri(v)},
                  ol: proc{|v| consume_next(:type_or_lang); @reader.object = v},
                  ll: proc{|v| consume_next(:object_literal); @reader.object_lang = v},
                  lt: proc{|v| consume_next(:object_literal); @reader.object_type = v},
                  nil => proc{ next_state(:skip_to_subj_or_pred) }
                }
              end
            end

            class ObjectSuffix < State
              def accept_list
                {
                  ov: proc{|v| consume_next(:object); triple_complete; @reader.object = @reader.object_prefix/v},
                  nil => proc{ next_state(:skip_to_subj_or_pred)}
                }
              end
            end

            class ObjectLiteral < State
              def accept_list
                {
                  ol: proc{|v| consume_next(:type_or_lang); @reader.object = v},
                  ll: proc{|v| consume; @reader.object_lang = v},
                  lt: proc{|v| consume; @reader.object_type = v},
                  nil => proc{ next_state(:skip_to_subj_or_pred)}
                }
              end
            end

            class TypeOrLang < State
              def accept_list
                {
                  ll: proc{|v| consume; @reader.object_lang = v},
                  lt: proc{|v| consume; @reader.object_type = v},
                  nil => proc{ next_state(:object); triple_complete }
                }
              end
            end
          end

          def initialize(input, options=nil, &block)
            super(input, options||{}, &block)

            @lineno = 0
            @new_triple = false

            @states = {
              :rdf => St::RDF.new(self),
              :def_ns_decl => St::DefNsDecl.new(self),
              :ns_decl => St::NsDecl.new(self),
              :ns_decl_suffix => St::NsDeclSuffix.new(self),
              :skip_to_subject => St::SkipToSubject.new(self),
              :skip_to_subj_or_pred => St::SkipToSubjectOrPred.new(self),
              :subject => St::Subject.new(self),
              :subject_suffix => St::SubjectSuffix.new(self),
              :predicate => St::Predicate.new(self),
              :predicate_suffix => St::PredicateSuffix.new(self),
              :object => St::Object.new(self),
              :object_suffix => St::ObjectSuffix.new(self),
              :object_literal => St::ObjectLiteral.new(self),
              :type_or_lang => St::TypeOrLang.new(self)
            }

            @current_state = @states.fetch(:rdf)
          end
          attr_reader :lineno, :states
          attr_accessor :current_state
          attr_accessor :new_triple, :subject, :predicate, :object
          attr_accessor :object_type, :object_lang
          attr_accessor :namespace_prefix, :subject_prefix, :predicate_prefix, :object_prefix

          def read_triple
            if @lineno >= @input.length
              raise EOFError
            end
            while @lineno < @input.length
              @current_state.accept(*@input[@lineno])
              if @new_triple
                @new_triple = false
                return build_triple
              end
            end
            return build_triple
          end

          def build_triple
            object = @object
            if object.is_a? String
              object = ::RDF::Literal.new(object, :datatype => object_type, :language => object_lang)
            end
            @object_type = nil
            @object_lang = nil

            [@subject, @predicate, object]
          end

          def rewind
            @lineno = 0
          end

          def consume_pair
            @lineno += 1
          end
        end

        def local_to_network(base_uri, graph)
        end

        def network_to_local(base_uri, list)
          raise "Invalid base uri: #{base_uri.inspect}" if base_uri.nil?
          graph = ::RDF::Graph.new
          reader = Reader.new(list, :base_uri => base_uri.to_s)
          reader.each_statement do |statement|
            graph.insert(statement)
          end
          graph
        end
      end
    end
  end
end
