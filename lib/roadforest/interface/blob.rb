require 'roadforest/interface/application'

module RoadForest
  module Interface
    class Blob < Application
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
end
