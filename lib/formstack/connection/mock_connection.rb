
require "webmock"
require "webmock/rspec"
include WebMock::API

root_path = File.dirname(__FILE__) + "/../../../spec/fixtures/"

module FormStack
	module ConnectionHelpers
		def simple_request(method, url, data, query_string = "", format = :json)
			has_id = !!(url =~ /(form|submission)\/\d/)

			file_name = "forms" if (url =~ /form/)
			file_name = "form" if (url =~ /form/ and has_id)
			file_name = "submission" if (url =~ /submission/ and has_id)
			file_name = "fields" if url =~ /field/
			file_name = "webhook" if url =~ /webhook/
			file_name = "confirmation" if url =~ /confirmation/

			plural = true if (url =~ /submission/ and has_id and url =~ /form/)

			file_response = File.read(File.dirname(__FILE__) + "/../../../spec/fixtures/#{file_name}.json")

			file_response = {"submissions" => [JSON.parse(file_response)]}.to_json if plural

			url = "#{@host}/#{url.to_s}.#{format.to_s}"

			data = data.send("to_#{format.to_s}") if data

			args = url
			args = ([args] << data) if (data and !JSON.parse(data).empty?)

			WebMock.stub_request(:get, url).to_return(:body => file_response) if method == :get
			WebMock.stub_request(:post, url).to_return(:body => {
			    "id" => "12345",
			}.to_json) if method == :post
			WebMock.stub_request(:delete, url).to_return(:body => {
			    "success" => "1",
			    "id" => "1"
			}.to_json) if method == :delete

			req = Curl::Easy.send("http_#{method.to_s}", *args) do |curl|
				curl.headers["Accept"] = FormStack::Connection::HEADERS_ACCEPT[format]
				curl.headers["Content-Type"] = FormStack::Connection::HEADERS_CONTENT_TYPE[format]
				curl.headers["Authorization"] = "Bearer #{@configuration[:access_token]}"
				curl.verbose = @debug
			end


			response = {:code => req.response_code, :response => req.body_str}
			return parse_response(response)
		end
	end
end
