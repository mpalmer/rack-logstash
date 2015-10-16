`Rack::Logstash` is a Rack-compliant middleware designed to satisfy all your
needs when it comes to logging Rack requests and responses to Logstash.  In
particular, it:

* Sends a log entry for each successful request/response, in a format
  compatible with grok's default APACHECOMBINEDLOG format (allowing easy
  integration with anything that understands those log entries);

* Catches all unhandled exceptions and logs them;

* Logs request headers for 4xx responses, and request and response headers
  for 5xx responses;

* Sends the log entries directly to a logstash server, using JSON-over-TCP.

If that sounds like the sort of thing you'd like to have, then this is the
middleware for you.


# Installation

It's a gem:

    gem install rack-logstash

There's also the wonders of [the Gemfile](http://bundler.io):

    gem 'rack-logstash'

If you're the sturdy type that likes to run from git:

    rake install

Or, if you've eschewed the convenience of Rubygems entirely, then you
presumably know what to do already.


# Usage

It is very simple to configure your Rack middleware stack to include
`Rack::Logstash`:

    require 'rack/logstash'

    use Rack::Logstash, "tcp://192.0.2.42:5151"

    run MyApp

That's all there is to it.  The middleware takes one mandatory argument, a
`tcp://` URL pointing to the logstash TCP input address and port.


## Tagging log entries

If you'd like to tag the log entries that `Rack::Logstash` emits, you can do
so using the `tags` option, like this:

    use Rack::Logstash, "tcp://192.0.2.42:5151",
                        :tags => ["foo", "bar", "baz"]

Any array of strings will be accepted.


## Logstash server config

You must have a `tcp` input plugin configured in your logstash server,
otherwise nothing is going to end well for you.  Specifically, your config
should look something very much like this:

    input {
      tcp {
        codec => "json_lines",
        port  => 5151
      }
    }

You can, of course, have other input plugins as well, and you can change the
port to whatever you like (as long as you adjust the port in the URL you
pass to `Rack::Logstash`).  The codec, however, *must* be `json_lines`.


# Contributing

Bug reports should be sent to the [Github issue
tracker](https://github.com/mpalmer/rack-logstash/issues), or
[e-mailed](mailto:theshed+rack-logstash@hezmatt.org).  Patches can be sent as a
Github pull request, or [e-mailed](mailto:theshed+rack-logstash@hezmatt.org).


# Licence

Unless otherwise stated, everything in this repo is covered by the following
copyright notice:

    Copyright (C) 2015  Matt Palmer <matt@hezmatt.org>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
