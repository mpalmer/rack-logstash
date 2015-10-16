require 'rack/request'

class Rack::Request
	def path_info_and_query_string
		path_info + (query_string.empty? ? "" : "?" + query_string)
	end

	def http_version
		server_protocol =~ %r{^HTTP/(.*)$} && $1
	end

	def server_protocol
		@env["SERVER_PROTOCOL"]
	end
end
