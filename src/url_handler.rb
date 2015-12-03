# -*- coding: utf-8 -*-
#require 'uri'
require 'addressable/uri'

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
  
  def sub_top
    "/r"
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
    Addressable::URI.parse("https://#{hostname()}/")
  end

  # [ is_multireddit , owner ]
  REGEX_USER_SUBMISSION_LISTS = "(submitted|upvoted|downvoted|hidden)"
  def path_is_multireddit(path)
    # reddit
    if m = path.match( /\/u(?:ser)?\/([\w\-]+)\/m\/\w+\/?$/ )
      m[ 1 ]
    elsif m = path.match( /\/u(?:ser)?\/([\w\-]+)\/#{REGEX_USER_SUBMISSION_LISTS}\/?$/ )
      m[ 1 ]
    elsif File.basename(path) =~ /\+/
      true
    elsif path == "../" # front
      true
    elsif path == "all"
      true
    elsif path == "friends"
      true
    else
      false
    end
  end
  
  def path_is_user_submission_list(path)
    if m = path.match( /\/u(?:ser)?\/([\w\-]+)\/#{REGEX_USER_SUBMISSION_LISTS}\/?$/ )
      m[ 1 ]
    else
      nil
    end
  end

  def subname_to_url(subname)
    abs_sub_top = base_url.join(sub_top + "/" )
    # abs_sub_top.merge( pe(subname) ) # multiへの相対パスの場合もあり
    abs_sub_top.join( subname ) # multiへの相対パスの場合もあり
  end

  def linkpath_to_url( path )
    #base_url.merge( pe(path) )
    base_url.join( path )
  end

  def parse_query(q )
    query_hash = {}
    q.split(/&/).map{|kv| 
      k,v = kv.split(/\=/)
      query_hash[ k ] = v
    }
    query_hash
  end

  def url_to_page_info( url )
    url = url.to_s
    $stderr.puts("url_to_page_info(#{url})")
    begin
      # url_o = URI.parse( pe(url) )
      url_o = Addressable::URI.parse( url)
    rescue
      return {:type => "other" , :url => url }
    end

    abs_url_o = if url_o.relative?
                  base_url.join( url_o )
                else
                  url_o
                end

    if rxp_site = TARGET_HOSTS.find{|r,s| abs_url_o.host =~ r }
      site = rxp_site[1]
      is_short = rxp_site[2]
      
      info = 
        if is_short
          if m = url_o.path.match( %r!^/(\w+)/?$! )
            {:site => site , :type => 'comment' , :name => m[1] }
          else
            {:type => "other" , :url => abs_url_o.to_s }
          end
        else
          if m = url_o.path.match( %r!^#{sub_top}/([\w\+]+)/?$!uo )
            {:site => site , :type => "sub" , :name => m[1] }
          elsif m = url_o.path.match( %r!^/u(?:ser)?/[\w\-]+/m/(\w+)/?$!uo )
            # /u/だとapiは転送してくれない？
            justified_path = url_o.path.sub( /^\/u\// , '/user/')
            {:site => site , :type => "sub" , :name => ".." + justified_path }
          elsif @account_name and m = url_o.path.match( %r!^/me/m/(\w+)/?$!uo )
            {:site => site , :type => 'sub' , :name => "../user/" + @account_name + "/m/" + m[1] }
          elsif m = url_o.path.match( %r!^/u(?:ser)?/[\w\-]+/#{REGEX_USER_SUBMISSION_LISTS}/?$!uo )
            # /u/だとapiは転送してくれない？
            justified_path = url_o.path.sub( /^\/u\// , '/user/')
            {:site => site , :type => "sub" , :name => ".." + justified_path }
          elsif @account_name and m = url_o.path.match( %r!^/me/#{REGEX_USER_SUBMISSION_LISTS}/?$!uo )
            {:site => site , :type => 'sub' , :name => "../user/" + @account_name + "/" + m[1] }
          elsif m = url_o.path.match( %r!^#{sub_top}/(\w+)/comments/(\w+)/[^/]*/(\w+)/?$!uo )
            {:site => site ,:type => "comment" , :name => m[2] , :top_comment => m[3] } # part comment
          elsif m = url_o.path.match( %r!^#{sub_top}/(\w+)/comments/(\w+)!uo )
            {:site => site ,:type=> "comment" , :name => m[2] }
          #elsif m = url_o.path.match( %r!^#{sub_top}/(\w+)/(\w+)!uo ) 
          # この形式がコメントかどうかをクライアント側で判定することはできない。redirect先を見るしかない
          #  {:site => site ,:type=> "comment" , :name => m[2] }
          elsif url_o.path == '/'
            {:site => site , :type => "sub" , :name => "../" } # front
          else # 非対応パス
            {:type => "other" , :url => abs_url_o.to_s }
          end
        end

      if url_o.query
        q = parse_query( url_o.query )
        info[:context] = q["context"] if q["context"]
        info[:sort]    = q["sort"] if q["sort"]
      end
      
      info[:account_name] = @account_name
      info
    else # 非対応サイト
      {:type => "other" , :url => abs_url_o.to_s }
    end
  end

end
