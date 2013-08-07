module RoadForest
  module ResourceMixin
    module FormParsing
      def self.content_types_accepted
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
  end
end
