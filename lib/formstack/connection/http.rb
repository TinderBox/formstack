module FormStack
	# shorthand helpers for status codes
	module ConnectionHelpers
		require "curb"
		require "addressable/uri"

		def get(o = {})
			url = o[:url]
			params = (o[:params] or o[:data] or {})

			param_string = ""
			if !params.empty?
				uri = Addressable::URI.new
				uri.query_values = params
				param_string = uri.query
			end

			return simple_request(:get, url, nil, param_string)
		end

		def post(o = {})
			url = o[:url]
			data = (o[:data] or o[:params] or {})

			return simple_request(:post, url, data)
		end

		def put(o = {})
			url = o[:url]
			data = (o[:data] or o[:params] or {})

			return simple_request(:put, url, data)
		end

		def delete(o = {})
			url = o[:url]
			data = (o[:data] or o[:params] or {})

			return simple_request(:delete, url, data)
		end

		def upload(o = {})
			url = o[:url] or @default_host
			data = (o[:data] or o[:params] or o[:fields] or {})
			format = (o[:format] or :json)
			file_name = o[:file_name]
			file_field_name = o[:file_field_name]

			url = "#{@host}/#{url}.#{format.to_s}?access_token=#{@configuration[:access_token]}"

			ap url if @debug

			post_fields = []
			post_fields << Curl::PostField.file(file_field_name, file_name)
			data.each do |name,obj|
				if obj and obj.is_a?(Hash)
					obj.each do |attribute, value|
						post_fields << Curl::PostField.content("#{name}[#{attribute}]", value)
					end
				end
			end

			c = Curl::Easy.new(url)
			c.multipart_form_post = true
			c.http_post(post_fields)

			response = {:code => c.response_code, :response => c.body_str}
			return parse_response(response)
		end

	protected

		def simple_request(method, url, data, query_string = "", format = :json )
			url = "#{@host}/#{url.to_s}.#{format.to_s}?#{query_string}"
			data = data.send("to_#{format.to_s}") if data

			args = url
			args = ([args] << data) if data and method != :delete
			ap args if @debug
			# we can only include he token in the url OR the header
			# some resources (encryped submissions) require the access token
			# be in he query string, and not the header...
			has_url_token = query_string.include?("oauth_token")
			req = Curl::Easy.send("http_#{method.to_s}", *args) do |curl|
				curl.headers["Accept"] = FormStack::Connection::HEADERS_ACCEPT[format]
				curl.headers["Content-Type"] = FormStack::Connection::HEADERS_CONTENT_TYPE[format]
				curl.headers["Authorization"] = "Bearer #{@configuration[:access_token]}" if !has_url_token
				curl.verbose = @debug
				# Temp disable until CA cert is updated.
				curl.ssl_verify_peer = false
			end

			response = {:code => req.response_code, :response => req.body_str}
			return parse_response(response)
		end

		def parse_response(response)
			body = response[:response]
			status = response[:code]
			ap body if @debug
			begin
				if status >= 400
					raise "HTTP Error: #{status}"
				end
				return {} if (body == " " or body == "") and status >= 200 and status < 300
				return JSON.parse(body)
			rescue => e
				ap e.message
				ap body
				ap status
				raise e
			end
		end
	end
end
