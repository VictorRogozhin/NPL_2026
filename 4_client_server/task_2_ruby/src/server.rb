require 'socket'
require 'json'
require 'uri'
require 'securerandom'
require 'timeout'

class ShortLinks
  class BadRequest < StandardError; end

  def initialize
    @links = {}
  end

  def serve(socket)
    method, path, body = Timeout.timeout(5) { read_request(socket) }
    if method == 'POST' && path == '/links'
      create(socket, body)
    elsif method == 'GET' && (match = %r{\A/stats/([0-9a-f]{8})\z}.match(path))
      entry = @links[match[1]]
      return respond(socket, '404 Not Found', { error: 'Unknown code' }) unless entry

      respond(socket, '200 OK', { visits: entry[:visits] })
    elsif method == 'GET' && (match = %r{\A/([0-9a-f]{8})\z}.match(path))
      entry = @links[match[1]]
      return respond(socket, '404 Not Found', { error: 'Unknown code' }) unless entry

      respond(socket, '302 Found', nil, 'Location' => entry[:url])
      entry[:visits] += 1
    else
      respond(socket, '404 Not Found', { error: 'Unknown route' })
    end
  rescue BadRequest, Timeout::Error
    respond(socket, '400 Bad Request', { error: 'Invalid request' })
  end

  private

  def read_request(socket)
    line = socket.gets("\n", 4096)
    request = line && /\A([A-Z]+) (\/[!-~]*) HTTP\/1\.[01]\r\n\z/n.match(line)
    raise BadRequest unless request

    headers = {}
    total = 0
    loop do
      line = socket.gets("\n", 4096)
      raise BadRequest unless line

      total += line.bytesize
      raise BadRequest if total > 8192
      break if line == "\r\n"

      header = /\A([A-Za-z0-9-]+):[ \t]*([\x20-\x7e]*)\r\n\z/n.match(line)
      raise BadRequest unless header

      name = header[1].downcase
      raise BadRequest if headers.key?(name)

      headers[name] = header[2].rstrip
    end
    raise BadRequest if headers.key?('transfer-encoding')

    length = headers.fetch('content-length', '0')
    raise BadRequest unless /\A[0-9]{1,5}\z/.match?(length) && length.to_i <= 8192

    body = socket.read(length.to_i)
    raise BadRequest unless body && body.bytesize == length.to_i

    [request[1], request[2], body]
  end

  def create(socket, body)
    raise BadRequest if body.match?(/%(?![0-9a-fA-F]{2})/)

    fields = URI.decode_www_form(body)
    raise BadRequest unless fields.size == 1 && fields[0][0] == 'url'

    url = fields[0][1]
    raise BadRequest unless /\A[!-~]+\z/.match?(url)

    uri = URI.parse(url)
    raise BadRequest unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?

    code = SecureRandom.hex(4)
    code = SecureRandom.hex(4) while @links.key?(code)
    @links[code] = { url: url, visits: 0 }
    respond(socket, '201 Created', { code: code, short_path: "/#{code}" })
  rescue URI::InvalidURIError, ArgumentError
    raise BadRequest
  end

  def respond(socket, status, data, headers = {})
    body = data ? JSON.generate(data) : ''
    lines = ["HTTP/1.1 #{status}", "Content-Length: #{body.bytesize}", 'Connection: close']
    lines << 'Content-Type: application/json' if data
    headers.each { |name, value| lines << "#{name}: #{value}" }
    socket.write(lines.join("\r\n") + "\r\n\r\n" + body)
  end
end

port = Integer(ARGV.fetch(0, '4042'), 10)
server = TCPServer.new('127.0.0.1', port)
application = ShortLinks.new
puts "Listening on http://127.0.0.1:#{port}"
$stdout.flush
loop do
  socket = server.accept
  begin
    application.serve(socket)
  rescue IOError, SystemCallError
    # A peer may disconnect while sending or receiving a request.
  ensure
    socket.close
  end
end
