require 'json'
require 'rack/logstash/extended_request'
require 'rack/logstash/transport'
require 'ipaddr'
require 'socket'

module Rack
	class Logstash
		def initialize(app, url, opts = {})
			@app    = app
			@server = Rack::Logstash::Transport.new(url)
			@tags   = opts.fetch(:tags, [])
		end

		def call(env)
			env['rack.logstash.start_time'] = Time.now

			begin
				@app.call(env).tap do |response|
					log_request(env, response)
				end
			rescue StandardError => ex
				log_exception(env, ex)
				raise
			end
		end

		private

		def log_request(env, response)
			@server.send(request_log_entry(env, response).to_json)
		end

		def request_log_entry(env, response)
			req = Rack::Request.new(env)
			res = Rack::Response.new(response[2], response[0], response[1])

			common_entry_fields(env).tap do |e|
				e['message']  = "#{req.ip} " +
				                "#{req.request_method} " +
				                "#{req.path_info_and_query_string} " +
				                "#{req.server_protocol} " +
				                "=> #{res.status}"
				e['ident']    = '-'
				e['auth']     = '-'
				e['response'] = res.status
				e['bytes']    = res.length

				# Log request details if we got a bad request
				if response.first >= 400 && response.first != 404
					e.merge!(request_detail_fields(env))
				end

				# Log response details if we got a bad response
				if response.first >= 500
					e.merge!(response_detail_fields(res))
				end
			end
		end

		def log_exception(env, ex)
			@server.send(exception_log_entry(env, ex).to_json)
		end

		def exception_log_entry(env, ex)
			req = Rack::Request.new(env)

			common_entry_fields(env).tap do |e|
				e['message']   = "#{req.ip} " +
				                 "#{req.request_method} " +
				                 "#{req.path_info_and_query_string} " +
				                 "#{req.server_protocol} " +
				                 "=> #{ex.message} (#{ex.class})"

				e['exception'] = {
					'class' => ex.class,
					'message' => ex.message,
					'backtrace' => ex.backtrace
				}

				e['pwd'] = Dir.getwd

				e.merge!(request_detail_fields(env))
			end
		end

		def common_entry_fields(env)
			req = Rack::Request.new(env)

			{
				'@version'            => 1,
				'type'                => 'rack-logstash',
				'tags'                => @tags,
				'clientip'            => req.ip,
				'timestamp'           => iso_time(env['rack.logstash.start_time']),
				'@timestamp'          => iso_time(env['rack.logstash.start_time']),
				'verb'                => req.request_method,
				'request'             => req.path_info_and_query_string,
				'httpversion'         => req.http_version,
				'rawrequest'          => "#{req.request_method} " +
				                         "#{req.path_info_and_query_string} " +
				                         "#{req.server_protocol}",
				'referrer'            => req.referer,
				'agent'               => req.user_agent,
				'time_duration'       => ((Time.now - env['rack.logstash.start_time']) * 1000).round,
				'host'                => Socket.gethostname,
				'pid'                 => $$,
				'program'             => $0,
				'request_header_host' => req.host,
			}.tap do |e|
				# Some conditionally set entries
				ip = IPAddr.new(e['clientip'])
				e['client_ip_v4'] = ip.to_s if ip.ipv4?
				e['client_ip_v6'] = ip.to_s if ip.ipv6?
			end
		end

		def request_detail_fields(env)
			{}.tap do |e|
				if io = env['rack.input']
					io.rewind if io.respond_to? :rewind
					e['request_body'] = io.read
					io.rewind if io.respond_to? :rewind
				end

				e['rack_environment'] = rack_environment(env)
			end
		end

		def rack_environment(env)
			Hash[
				env.map do |k, v|
					unless v.is_a? Hash or
					       v.is_a? Array or
					       v.is_a? String or
					       v.is_a? Numeric
						next nil
					end

					if k == 'HTTP_AUTHORIZATION' && v =~ /^Basic /
						v = "Basic *filtered*"
					end

					[k, v]
				end.compact
			]
		end

		def response_detail_fields(res)
			{
				'response_headers' => res.headers,
				'response_body'    => res.body.join
			}
		end

		def iso_time(t)
			t.utc.strftime("%FT%T.%LZ")
		end
	end
end
