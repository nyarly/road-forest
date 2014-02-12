require 'roadforest/model'
require 'roadforest/content-handling/type-handlers/jsonld'

module RoadForest
  class BlobModel < Model
    TypeHandlers = RoadForest::MediaType::Handlers

    #XXX Where should ContentHandling live?
    #Embedded in the class is ... easy, but hard to test
    class << self
      def type_handling
        @engine ||= ContentHandling::Engine.new
      end

      def add_type(handler, type)
        type_handling.add_type(handler, type)
      end
      alias add add_type
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
