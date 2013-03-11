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
    route = @routes[r.method].select {|path| path[0] == r.path}
    if route.size > 0
      param = {}
      if r.headers['Content-Type'] == 'application/x-www-form-urlencoded'
        r.body.split('&').each do |x|
          tokens = x.split('=', 2)
          if tokens && tokens.size == 2
            param[tokens[0]] = HTTP::URL::decode(tokens[1])
          end
        end
      end
      @content_type = 'text/html; charset=utf-8'
      bb = route[0][2].call(r, param).to_s
      return [
        "HTTP/1.0 200 OK",
        "Content-Type: #{@content_type}",
        "Content-Length: #{bb.size}",
        "", ""].join("\r\n") + bb
    end
    if r.method == 'GET'
      f = nil
      begin
        file = r.path + (r.path[-1] == '/' ? 'index.html' : '')
        ext = file.split(".")[-1]
        ctype = ['txt', 'html', 'css'].index(ext) ? "text/" + ext :
                ['js'].index(ext) ? "text/javascript" :
                 'application/octet-stream'
        f = UV::FS::open("static#{file}", UV::FS::O_RDONLY, UV::FS::S_IREAD)
        bb = ''
        while (read = f.read(4096, bb.size)).size > 0
          bb += read
        end
        return [
            "HTTP/1.0 200 OK",
            "Content-Type: #{ctype}; charset=utf-8",
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
