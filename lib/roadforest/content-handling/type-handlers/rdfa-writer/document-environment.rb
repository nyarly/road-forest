require 'roadforest/content-handling/type-handlers/rdfa-writer/render-environment'
module RoadForest::MediaType
  class RDFaWriter
    class DocumentEnvironment < RenderEnvironment
      attr_accessor :subject_terms, :title, :prefixes, :lang, :base
      def yielded(item)
        @_engine.render(item)
      end

      def subjects
        enum_for(:each_subject_environment)
      end

      def each_subject_environment
        subject_terms.each do |term|
          yield @_engine.subject_env(term)
        end
      end

      def template_kinds
        %w{doc}
      end

      def prefix
        @prefix ||=
          if prefixes.empty?
            nil
          else
            prefixes.keys.map {|pk| "#{pk}: #{prefixes[pk]}"}.sort.join(" ")
          end.tap{|prefix| add_debug {"\nserialize: prefixes: #{prefixes.inspect} prefix src: #{prefix.inspect}"}}
      end
    end
  end
end
