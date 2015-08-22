# -*- coding: utf-8 -*-
require 'uri'

class UrlHandler
  def initialize( site = 'reddit' , account_name:nil)
    @site = site
    @account_name = account_name
  end

  # reddit互換サイト
  TARGET_HOSTS = [
                  [/^\w+\.reddit\.com$/ , 'reddit' , false],
                  [/^reddit\.com$/ , 'reddit' , false],
                  [/^redd\.it$/ , 'reddit' , true] 
                 ]

  def hostname()
    case @site
    when 'reddit'
      'www.reddit.com'
    end
  end
  
  attr_accessor :account_name

  def percent_encode_only_not_ascii( string_utf8 )
    ret = ""
    string_utf8.force_encoding("ascii-8bit").each_char{|c|
      if c.ord >= 128
        ret << "%%%02x" % c.ord
      else
        ret << c
      end
    }
    ret
  end
  alias :pe :percent_encode_only_not_ascii

  def base_url
    URI.parse("https://#{hostname()}/")
  end

  # [ is_multireddit , owner ]
  def path_is_multireddit(path)
    # reddit
    if m = path.match( /\/u(?:ser)?\/([\w\-]+)\/m\/\w+\/?$/ )
      m[ 1 ]
    elsif File.basename(path) =~ /\+/
      true
    elsif path == "../" # front
      true
    elsif path == "all"
      true
    else
      false
    end
  end
  
  def subname_to_url(subname)
    subtop = case @site
             when 'reddit'
               base_url.merge('/r/')
             end
    subtop.merge( pe(subname) ) # multiへの相対パスの場合もあり
  end

  def linkpath_to_url( path )
    base_url.merge( pe(path) )
  end

  

  def url_to_page_info( url )
    url = url.to_s
    $stderr.puts("url_to_page_info(#{url})")
    begin
      url_o = URI.parse( pe(url) )
    rescue
      return {:type => "other" , :url => url }
    end

    abs_url_o = if url_o.relative?
                  base_url.merge( url_o )
                else
                  url_o
                end

    if rxp_site = TARGET_HOSTS.find{|r,s| abs_url_o.host =~ r }
      site = rxp_site[1]
      is_short = rxp_site[2]
      
      if is_short
        if m = url_o.path.match( %r!^/(\w+)/?$! )
          {:site => site , :type => 'comment' , :name => m[1] }
        else
          {:type => "other" , :url => abs_url_o.to_s }
        end
      else
        # todo: /r/ が固定であるし
        if m = url_o.path.match( %r!^/r/(\w+)/?$!uo )
          {:site => site , :type => "sub" , :name => m[1] }
        elsif m = url_o.path.match( %r!^/u(?:ser)?/[\w\-]+/m/(\w+)/?$!uo )
          {:site => site , :type => "sub" , :name => ".." + url_o.path }
        elsif @account_name and m = url_o.path.match( %r!^/me/m/(\w+)/?$!uo )
          {:site => site , :type => 'sub' , :name => "../user/" + @account_name + "/m/" + m[1] }
        elsif m = url_o.path.match( %r!^/r/(\w+)/comments/(\w+)/[^/]*/(\w+)/?$!uo )
          {:site => site ,:type => "comment" , :name => m[2] , :top_comment => m[3] } # part comment
        elsif m = url_o.path.match( %r!^/r/(\w+)/comments/(\w+)!uo )
          {:site => site ,:type=> "comment" , :name => m[2] }
        elsif url_o.path == '/'
          {:site => site , :type => "sub" , :name => "../" } # front
        else # 非対応パス
          {:type => "other" , :url => abs_url_o.to_s }
        end
      end
      
    else # 非対応サイト
      {:type => "other" , :url => abs_url_o.to_s }
    end
  end

end
