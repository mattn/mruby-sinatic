module Sinatic
  @content_type = nil
  @routes = { 'GET' => [], 'POST' => [] }
  def self.route(method, path, opts, &block)
    @routes[method] << [path, opts, block]
  end
  def self.content_type(type)
    @content_type = type
  end
  def self.do(r)
    @routes[r.method].each do |path|
      if path[0] == r.path
        param = {}
        r.body.split('&').each do |x|
          tokens = x.split('=', 2)
          param[tokens[0]] = HTTP::URL::decode(tokens[1])
		end
        @content_type = 'text/html; charset=utf-8'
        bb = path[2].call(r, param)
        return [
          "HTTP/1.0 200 OK",
          "Content-Type: #{@content_type}",
          "Content-Length: #{bb.size}",
          "", ""].join("\r\n") + bb
      end
	end
    if r.method == 'GET'
      f = nil
      begin
        f = UV::FS::open("static#{r.path}", UV::FS::O_RDONLY|UV::FS::O_BINARY, UV::FS::S_IREAD)
        bb = ''
        while (read = f.read()).size > 0
          bb += read
        end
        return [
            "HTTP/1.0 200 OK",
            "Content-Type: application/octet-stream; charset=utf-8",
            "Content-Length: #{bb.size}",
            "", ""].join("\r\n") + bb
      rescue RuntimeError
      ensure
        f.close if f
      end
    end
    return "HTTP/1.0 404 Not Found\r\nContent-Length: 10\r\n\r\nNot Found\n"
  end
  def self.run(options = {})
    s = UV::TCP.new()
    config = {:host => '127.0.0.1', :port => 8888}.merge(options)
    s.bind(UV::ip4_addr(config[:host], config[:port]))
    s.listen(2000) do |x|
      return if x != 0
      c = s.accept()
      c.read_start do |b|
        return unless b
        i = b.index("\r\n\r\n")
        return if i < 0
        r = HTTP::Parser.new.parse_request(b)
        r.body = b.slice(i + 4, b.size - i - 4)
        bb = ::Sinatic.do(r)
        if !r.headers.has_key?('Connection') || r.headers['Connection'] != 'Keep-Alive'
          c.write(bb) do |x|
            c.close() if c
            c = nil
          end
        else
          c.write(bb)
        end
      end
    end

    t = UV::Timer.new
    t.start(3000, 3000) {|x|
      UV::gc()
      GC.start
    }

    UV::run()
  end
end

module Kernel
  def get(path, opts={}, &block)
    ::Sinatic.route 'GET', path, opts, &block
  end
  def post(path, opts={}, &block)
    ::Sinatic.route 'POST', path, opts, &block
  end
  def content_type(type)
    ::Sinatic.content_type type
  end
end

# vim: set fdm=marker:
