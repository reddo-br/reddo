# -*- coding: utf-8 -*-
require 'open-uri'
require 'url_handler'
require 'css_parser'
require 'fileutils'
require 'util'

class SubStyle
  @@cache = {}
  def self.from_subname( subname , site:"reddit")
    @@cache[ [subname,site] ] || ( @@cache[[subname,site]] = self.new( subname ,site) )
  end
  
  def initialize( subname ,site)
    @subname = subname
    @site = site

    @uh = UrlHandler.new( site:site )
    @styles_cache_dir = (Util.get_appdata_pathname + "cache") + "redditmedia"
    FileUtils.mkdir_p( @styles_cache_dir )

    @stamp_style = nil
  end

  def get_stamp_style
    if @refresh_thread and @refresh_thread.alive?
      @refresh_thread.join
      @stamp_style
    else
      if @stame_style
        @stamp_style
      else
        @refresh_thread = Thread.new{ refresh }
        @refresh_thread.join
        @stamp_style
      end
    end
  end

  def refresh
    if raw_css = get_css
      stamp_css = ""
      parser = CssParser::Parser.new
      # parser.load_string!( raw_css , :base_uri => @uh.base_uri.to_s )
      parser.load_string!( raw_css )
      parser.each_selector(){ |sel , decl , spec |
        decl2 = decl.gsub(/url\("\/\// , 'url("https://' )
        sel.split(/,/).each{|sel2|
          if sel2 !~ /\.side/ and (sel2 =~ /a\[href/ or sel2 =~ /flair/)
            sel2.gsub!(/:lang\(\w+\)/,'')
            if selector_is_anchor(sel2)
              sel3 = ".md " + remove_ancestor( sel2 )
              decl3 = decl2 + ";text-decoration:none;" # redditのデフォルトにあわせる
            else
              sel3 = sel2
              decl3 = decl2
            end
            # animation関連は消す どうせcss-parserは @keyframe を解析できない
            decl4 = decl3.split(/;/).delete_if{|d| d =~ /animation[^"]*?:/}.join(";")
            
            stamp_css << "#{sel3.strip} {#{decl4}}\n"
          end
        }
      }
      @stamp_style = stamp_css
    end
  end

  def get_css_url( subreddit_name )
    url = "https://www.reddit.com/r/#{subreddit_name}/search"
    # p url
    body = open( url , "Range" => "bytes=-4096" , "Cookie" => "over18=1" ){|cn| cn.read }
    if m = body.match( /https?:\/\/[\w\-\.]+\.redditmedia\.com\/[\w\-\_]+\.css/)
      m[0]
    else
      nil
    end
  end

  def selector_is_anchor( sel )
    targets = sel.split(/[ >]/)
    targets.find{|t| t == 'a' or t =~ /^a[:\[]/}
  end

  def remove_ancestor( sel )
    targets = sel.split(/[ >]/).map{|e| e.strip }
    # p targets1
    if pos = targets.find_index{|t| t == '.md' }
      t2 = targets[ (pos+1) .. -1]
      if t2.to_a.length > 0
        t2.join(" ")
      else
        sel
      end
    elsif pos = targets.find_index{|t| t == '.usertext-body' }
      t2 = targets[ (pos+1) .. -1 ]
      if t2.to_a.length > 0
        t2.join(" ")
      else
        sel
      end
    else
      sel
    end
  end

  def get_css
    begin
      if css_url = get_css_url( @subname )
        css_cache = css_url_to_cache_path( css_url )
        if File.exist?( css_cache )
          $stderr.puts "cssキャッシュを使用 #{css_cache}"
          File.read( css_cache )
        else
          css = open( css_url ){|cn| cn.read }
          open( css_cache , 'w'){|f| f.write css }
          css
        end
      else
        ""
      end
    rescue
      $stderr.puts $!
      $stderr.puts $@
      nil
    end
  end

  def css_url_to_cache_path(url)
    file = url.gsub(/^https?:\/\// , '').gsub(/\// , '.' )
    (@styles_cache_dir + file).to_s
  end

end

# test
if File.basename($0) == File.basename( __FILE__ )
  s = SubStyle.from_subname( ARGV.shift || "bakanewsja" )
  puts s.get_stamp_style
end
