require 'tweetstream'
require 'em-http-request'
require 'json'
require 'zlib'

class HttpConnectionOptions
  alias_method :__original_initialize, :initialize

  def initialize(uri, options)
    __original_initialize(uri, options)
    @host = options[:host] if options[:host]
  end
end


class LinkTrack
  class Stats
    Stats = %w{
             dns_inflight
             redirects redirect_loops dns_errors
             urls http_errors nohtml
             hostcache_flushs
             incoming_urls
            }

    Stats.each do |s|
      attr_accessor s
    end
    attr_accessor :inflight

    def initialize
      Stats.each do |var|
        instance_variable_set('@'+var, 0)
      end
      @inflight = []
    end

    def to_s
      instance_variables.map do |var|
        val = instance_variable_get(var)
        if val.respond_to? :length
          val = val.length
        end
        "#{var[1..-1]}: #{val}"
      end.join(", ")
    end
  end

  def self.run(&blk)
    t = LinkTrack.new
    t.run(&blk)
  end

  def initialize
    TweetStream.configure do |config|
      JSON(File.read(File.expand_path("../auth.conf", $0))).each do |k,v|
        config.send("#{k}=", v)
      end
    end

    @hostcache = {}

    @stats = Stats.new
  end

  def process_url(url, try = 0)
    return if not url

    @stats.incoming_urls += 1

    if @stats.incoming_urls % 100 == 0
      puts @stats
    end

    m = url.match(/^(\w+:\/\/)([^:\/]+)(.*)/)
    return if not m

    host = m[2]

    if !@hostcache[host]
      @stats.dns_inflight += 1
      # need to resolve hostname first
      dnsreq = EM::DNS::Resolver.resolve host
      dnsreq.errback do
        @stats.dns_inflight -= 1
        @stats.dns_errors += 1
      end
      dnsreq.callback do |addrs|
        @stats.dns_inflight -= 1
        if addrs.empty?
          @stats.dns_errors += 1
        else
          if @hostcache.size > 10000
            @hostcache = {}
            @stats.hostcache_flushs += 1
          end
          @hostcache[host] = addrs.first
          resolve_redirect(url, @hostcache[host], try)
        end
      end
    else
      resolve_redirect(url, @hostcache[host], try)
    end
  end

  def resolve_redirect(url, host, try, method=:head)
    req = EventMachine::HttpRequest.new(url, {:host => host, :head => {'User-Agent' => 'mozilla'}}).setup_request(method)
    @stats.inflight << req
    req.headers do
      @stats.inflight.delete(req)
      newurl = req.response_header['Location']
      # Seems some servers might send several Location headers
      if newurl.respond_to? :last
        newurl = newurl.last
      end
      if newurl
        @stats.redirects += 1

        if try > 10
          @stats.redirect_loops += 1
        else
          process_url(newurl, try + 1)
        end
      else
        ct = req.response_header['Content-type']
        if !ct || req.response_header.status >= 300
          if method == :get
            @stats.http_errors += 1
          else
            resolve_redirect(url, host, try + 1, :get)
          end
        else
          ct = [ct] if not Array === ct
          if ct.grep(/html/).empty?
            @stats.nohtml += 1
          else
            @stats.urls += 1
            @cb.call(url)
          end
        end
      end
    end

    req.errback do
      @stats.inflight.delete(req)
    end
  end

  def run(&blk)
    @cb = blk

    EM.run do
      TweetStream::Client.new.track('http', 'https') do |t|
        begin
          urls = t.urls.map{|u| u.expanded_url}
          if not urls
            urls = t.retweeted_status.urls.map{|u| u.expanded_url}
          end
          next if urls.empty?

          urls.each do |u|
            process_url(u)
          end
        rescue NoMethodError
          # meh bug in em-http-request
        rescue Exception => e
          puts(([e.to_s]+e.backtrace).join("\n"))
          raise
        end
      end
    end
  end
end


class GzipBreakableFile
  def self.open(*a)
    bf = GzipBreakableFile.new(*a)

    if block_given?
      begin
        yield bf
      ensure
        bf.close
      end
    else
      bf
    end
  end

  def initialize(basename)
    @basename = basename

    open_new_file
  end

  def open_new_file
    sufx = Time.now.strftime("%Y%m%dT%H%M%S")
    newname = "%s-%s.gz" % [@basename, sufx]
    if @f
      @f.close
      @f = nil
    end
    @f = Zlib::GzipWriter.open(newname)
  end

  def method_missing(*a)
    @f.send(*a)
  end
end


if $0 == __FILE__
  if ARGV.empty?
    LinkTrack.run do |url|
      puts url
    end
  else
    GzipBreakableFile.open(ARGV.first) do |bf|
      nurl = 0
      LinkTrack.run do |url|
        bf.puts url
        nurl += 1
        if nurl >= 100000
          bf.open_new_file
          nurl = 0
        end
      end
    end
  end
end
