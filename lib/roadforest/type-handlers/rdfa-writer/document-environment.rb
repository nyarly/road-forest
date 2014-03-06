require 'roadforest/type-handlers/rdfa-writer/render-environment'

module RoadForest::TypeHandlers
  class RDFaWriter
    class DocumentEnvironment < RenderEnvironment
      attr_accessor :subject_terms, :title, :prefixes, :lang, :base

      def subjects
        enum_for(:each_subject_environment)
      end

      def each_subject_environment
        subject_terms.each do |term|
          yield subject_env(term)
        end
      end

      def template_kinds
        %w{doc}
      end

      def build_prefix_header(prefixes)
          if prefixes.empty?
            nil
          else
            prefixes.keys.map {|pk| "#{pk}: #{prefixes[pk]}"}.sort.join(" ")
          end.tap{|prefix| add_debug {"\nserialize: prefixes: #{prefixes.inspect} prefix src: #{prefix.inspect}"}}
      end

      def prefix
        @prefix ||= build_prefix_header(prefixes)
      end
    end
  end
end
