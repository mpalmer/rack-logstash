require 'socket'
require 'thread'
require 'uri'

module Rack
	class Logstash
		class Transport
			def initialize(url)
				@url     = url
				@backlog = []
				@blmutex = Mutex.new
				@sender  = sender_thread
			end

			def send(s)
				@blmutex.synchronize { @backlog << s }
				@sender.run
			end

			def drain
				until @blmutex.synchronize { @backlog.empty? }
					sleep 0.001
				end
			end

			private

			def sender_thread
				Thread.new do
					loop do
						begin
							until @blmutex.synchronize { @backlog.empty? }
								s = @blmutex.synchronize { @backlog.shift }
								begin
									socket.puts s
								rescue Errno::EPIPE
									@socket.close
									@socket = nil
									retry
								end
							end
							Thread.stop
						rescue Exception => ex
							@stderr.puts "sender_thread died!  #{ex.message} (#{ex.class})"
							$stderr.puts ex.backtrace.map { |l| "  #{l}" }
						end
					end
				end
			end

			def socket
				begin
					@socket ||= TCPSocket.new(host, port)
				rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => ex
					$stderr.puts "rack-logstash: #{ex.class} while attempting to connect to #{host}:#{port}... retrying"
					sleep 0.1
					retry
				end
			end

			def host
				parsed_url.host
			end

			def port
				parsed_url.port
			end

			def parsed_url
				@parsed_url ||= URI(@url).tap do |url|
					if url.scheme != "tcp"
						raise ArgumentError,
								"Unknown scheme for Logstash server URL: " +
								url.scheme.inspect +
								" (we only accept 'tcp')"
					end
				end
			end
		end
	end
end
