require_relative './spec_helper'
require 'rack/logstash'
require 'rack/test'

describe Rack::Logstash do
	include Rack::Test::Methods

	let(:logstash_url) { "tcp://logstash:5151" }

	let(:app) do
		url = logstash_url
		res = response

		Rack::Builder.new do
			use Rack::Logstash, url

			run proc { |env| res }
		end
	end

	let(:mock_transport) { double(Rack::Logstash::Transport) }
	# This... is evil
	let(:log_entry)   { {} }

	before :each do
		expect(Rack::Logstash::Transport).
		  to receive(:new).
		  with('tcp://logstash:5151').
		  and_return(mock_transport)

		expect(mock_transport).to receive(:send) do |s|
			log_entry.replace(JSON.parse(s))
		end

		allow(Socket).
		  to receive(:gethostname).
		  and_return("server.example.com")
	end

	let(:response) { [200, [], ["OK"]] }

	context "a simple request" do
		before :each do
			expect(Time).
			  to receive(:now).
			  with(no_args).
			  and_return(
			    Time.at(1234567890).utc,
			    Time.at(1234567890.01).utc
			  ).at_least(2)

			get '/', {}, { 'SERVER_PROTOCOL' => "HTTP/1.1" }
		end

		it "sends a log entry" do
			expect(log_entry).to_not be_empty
		end

		it "logs a reasonable-looking message" do
			expect(log_entry['message']).to eq("127.0.0.1 GET / HTTP/1.1 => 200")
		end

		it "logs the client IP" do
			expect(log_entry['clientip']).to eq('127.0.0.1')
		end

		it "logs the v4 client IP" do
			expect(log_entry['client_ip_v4']).to eq('127.0.0.1')
		end

		it "logs ident" do
			expect(log_entry['ident']).to eq('-')
		end

		it "logs auth" do
			expect(log_entry['auth']).to eq('-')
		end

		it "logs the timestamp" do
			expect(log_entry['timestamp']).to eq(Time.now.strftime("13/Feb/2009:23:31:30 +0000"))
		end

		it "logs the verb" do
			expect(log_entry['verb']).to eq("GET")
		end

		it "logs the request path" do
			expect(log_entry['request']).to eq('/')
		end

		it "logs the HTTP version" do
			expect(log_entry['httpversion']).to eq('1.1')
		end

		it "logs the whole raw request" do
			expect(log_entry['rawrequest']).to eq("GET / HTTP/1.1")
		end

		it "logs the response status" do
			expect(log_entry['response']).to eq(200)
		end

		it "logs the response size" do
			expect(log_entry['bytes']).to eq(2)
		end

		it "logs the type" do
			expect(log_entry['type']).to eq('rack-logstash')
		end

		it "logs the elapsed time" do
			expect(log_entry['time_duration']).to eq(10)
		end

		it "logs the server's FQDN" do
			expect(log_entry['host']).to eq('server.example.com')
		end

		it "logs the server's PID" do
			expect(log_entry['pid']).to eq($$)
		end

		it "logs the server's program" do
			expect(log_entry['program']).to eq($0)
		end

		it "logs the Host header" do
			expect(log_entry['request_header_host']).to eq('example.org')
		end
	end

	context "a simple request over IPv6" do
		before :each do
			get '/', {}, { 'SERVER_PROTOCOL' => "HTTP/1.1",
			               "REMOTE_ADDR" => "2001:db8::feed:b00f"
			             }
		end

		it "sends a log entry" do
			expect(log_entry).to_not be_empty
		end

		it "logs the client IP" do
			expect(log_entry['clientip']).to eq('2001:db8::feed:b00f')
		end

		it "logs the v6 client IP" do
			expect(log_entry['client_ip_v6']).to eq('2001:db8::feed:b00f')
		end

		it "doesn't log a v4 client IP" do
			expect(log_entry).to_not have_key('client_ip_v4')
		end
	end

	context "with tags" do
		let(:app) do
			url = logstash_url
			res = response

			Rack::Builder.new do
				use Rack::Logstash, url, :tags => ["foo", "bar"]

				run proc { |env| res }
			end
		end

		before :each do
			get '/', {}, { 'SERVER_PROTOCOL' => "HTTP/1.1" }
		end

		it "sends a log entry" do
			expect(log_entry).to_not be_empty
		end

		it "sends the tags" do
			expect(log_entry['tags']).to eq(["foo", "bar"])
		end
	end

	context "when the app raises an exception" do
		let(:app) do
			url = logstash_url
			res = response

			Rack::Builder.new do
				use Rack::Logstash, url

				run proc { |env| raise RuntimeError, "THWACKOOM" }
			end
		end

		before :each do
			begin
				get '/', {}, { 'SERVER_PROTOCOL' => "HTTP/1.1" }
			rescue RuntimeError => ex
				raise unless ex.message == "THWACKOOM"
			end
		end

		it "sends a log entry" do
			expect(log_entry).to_not be_empty
		end

		it "logs a reasonable-looking message" do
			expect(log_entry['message']).to eq("127.0.0.1 GET / HTTP/1.1 => THWACKOOM (RuntimeError)")
		end

		it "sends exception data" do
			expect(log_entry).to have_key('exception')
			expect(log_entry['exception']).to_not be_empty
		end

		it "sends an exception class" do
			expect(log_entry['exception']['class']).to eq("RuntimeError")
		end

		it "sends an exception message" do
			expect(log_entry['exception']['message']).to eq("THWACKOOM")
		end

		it "sends an exception backtrace" do
			expect(log_entry['exception']['backtrace']).to be_an(Array)
		end

		it "sends the rack environment" do
			expect(log_entry).to have_key('rack_environment')
			expect(log_entry['rack_environment']).to_not be_empty
		end
	end
end
