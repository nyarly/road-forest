require 'roadforest/model'
require 'roadforest/content-handling/type-handlers/jsonld'

module RoadForest
  class BlobModel < Model
    TypeHandlers = RoadForest::MediaType::Handlers
    class << self
      def type_handling
        @engine ||= ContentHandling::Engine.new
      end

      def add_type(type, handler)
        add_parser(type, handler)
        add_renderer(type, handler)
      end
      alias add add_type

      def add_parser(type, handler)
        type_handling.add_parser(type, handler)
      end

      def add_renderer(type, handler)
        type_handling.add_renderer(type, handler)
      end
    end

    def type_handling
      self.class.type_handling
    end

    def destination_dir
      Pathname.new(services.destination_dir)
    end

    def sub_path
      params.remainder
    end

    def path
      destination_dir.join(sub_path)
    end

    def retrieve
      File::open(path)
    end

    def incomplete_path
      [path,"incomplete"].join(".")
    end

    def update(incoming)
      File::open(incomplete_path, "w") do |file|
        incoming.each do |chunk|
          file.write(chunk)
        end
      end
      Pathname.new(incomplete_path).rename(path)

      return nil
    end
  end
end
