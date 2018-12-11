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
  REGEX_USER_SUBMISSION_LISTS = "(?:submitted|upvoted|downvoted|hidden)"
  REGEX_USER_COMMENT_LISTS = "(?:comments|saved|gilded\/given|gilded)"

  REGEX_SUBMISSION_COMMENT_LIST = "(?:comments|gilded)"
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
    elsif path =~ /^all\-/ # filterd all
      true
    elsif path == "friends"
      true
    elsif path == "popular"
      true
    elsif path == "mod"
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

  def path_is_user_comment_list(path)
    if m = path.match( /\/u(?:ser)?\/([\w\-]+)\/#{REGEX_USER_COMMENT_LISTS}\/?$/ )
      m[ 1 ]
    elsif m = path.match( /\/u(?:ser)?\/([\w\-]+)\/?$/ )
      m[ 1 ]
    else
      nil
    end
  end

  def path_is_subreddit_comment_list(path)
    if m = path.match( /\/r\/([\w\-]+)\/(comments|gilded)\/?$/ )
      [ m[ 1 ] , m[ 2 ] ]
    elsif m = path.match( /\/(comments|gilded)\/?$/ )
      [ nil , m[1] ]
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

    url_o = if url_o.relative?
              base_url.join( url_o )
            else
              url_o
            end

    if rxp_site = TARGET_HOSTS.find{|r,s| url_o.host =~ r }
      site = rxp_site[1]
      is_short = rxp_site[2]
      
      info = 
        if is_short
          if m = url_o.path.match( %r!^/(\w+)/?$! )
            {:site => site , :type => 'comment' , :name => m[1] }
          else
            {:type => "other" , :url => url_o.to_s }
          end
        else
          ####### sub
          if m = url_o.path.match( %r!^#{sub_top}/([\w\+]+)/?$!uo )
            title = m[1] # 暫定
            {:site => site , :type => "sub" , :name => m[1] , :title => title}

            ##### subのコメント一覧
          elsif m = url_o.path.match( %r!^#{sub_top}/([\w\+]+)/(#{REGEX_SUBMISSION_COMMENT_LIST})/?$!uo)
            title = submission_comment_list_title( m[2] ) + " [#{m[1]}]"
            {:site => site , :type => "comment-post-list" , :name => url_o.path , :title => title }
          elsif m = url_o.path.match( %r!^/(#{REGEX_SUBMISSION_COMMENT_LIST})/?$!uo)
            title = submission_comment_list_title( m[1] ) + " [フロント]"
            {:site => site , :type => "comment-post-list" , :name => url_o.path , :title => title }
            
            ###### マルチレディット
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/m/(\w+)/?$!uo )
            # /u/だとapiは転送してくれない？
            justified_path = url_o.path.sub( /^\/u\// , '/user/')
            title = "#{m[2]} (#{m[1]})"
            {:site => site , :type => "sub" , :name => ".." + justified_path , :title => title}
          elsif @account_name and m = url_o.path.match( %r!^/me/m/(\w+)/?$!uo )
            title = "#{m[1]} (#{@account_name})"
            {:site => site , :type => 'sub' , :name => "../user/" + @account_name + "/m/" + m[1] ,
            :title => title}
          elsif m = url_o.path.match( %r!^#{sub_top}/(all\-[\w\-]+)/?$!uoi ) # filterd all     
            title = m[1].gsub(/\-/,' -')
            {:site => site , :type => "sub" , :name => m[1] , :title => title}
            
            ###### マルチレディットのコメント一覧
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/m/(\w+)/(#{REGEX_SUBMISSION_COMMENT_LIST})/?$!uo )
            # /u/だとapiは転送してくれない？
            justified_path = url_o.path.sub( /^\/u\// , '/user/')
            title1 = submission_comment_list_title( m[3] )
            title = "#{title1} [#{m[2]}](#{m[1]})"
            {:site => site , :type => "comment-post-list" , :name => justified_path , :title => title}
          elsif @account_name and m = url_o.path.match( %r!^/me/m/(\w+)/(#{REGEX_SUBMISSION_COMMENT_LIST})/?$!uo )
            title1 = submission_comment_list_title( m[2] )
            title = "#{title1} [#{m[1]}](#{@account_name})"
            {:site => site , :type => 'comment-post-list' , :name => "/user/" + @account_name + "/m/" + m[1] + "/" + m[2] ,
            :title => title}
            
            ###### user履歴 submission
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/(#{REGEX_USER_SUBMISSION_LISTS})/?$!uo )
            # /u/だとapiは転送してくれない？
            justified_path = url_o.path.sub( /^\/u\// , '/user/')
            title = user_list_title( m[2] ) + " (#{m[1]})"
            {:site => site , :type => "sub" , :name => ".." + justified_path , :title => title}
            
            ##### user履歴 コメント
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/?$!uo )
            title = "コメントと投稿 (#{m[1]})"
            {:site => site , :type => "comment-post-list" , :name => "/user/#{m[1]}" , :title => title}
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/(#{REGEX_USER_COMMENT_LISTS})/?$!uo )
            title = user_list_title( m[2] ) + " (#{m[1]})"
            {:site => site , :type => "comment-post-list" , :name => "/user/#{m[1]}/#{m[2]}" , 
            :title => title}

            ##### comment画面
          elsif m = url_o.path.match( %r!^#{sub_top}/(\w+)/comments/(\w+)/[^/]*/(\w+)/?$!uo )
            {:site => site ,:type => "comment" , :name => m[2] , :top_comment => m[3] , :subreddit => m[1] } # part comment
          elsif m = url_o.path.match( %r!^#{sub_top}/(\w+)/comments/(\w+)!uo )
            {:site => site ,:type=> "comment" , :name => m[2] , :subreddit => m[1] }
          #elsif m = url_o.path.match( %r!^#{sub_top}/(\w+)/(\w+)!uo ) 
          # この形式がコメントかどうかをクライアント側で判定することはできない。redirect先を見るしかない
          #  {:site => site ,:type=> "comment" , :name => m[2] }

            ##### user投稿のcomment画面
            # subreddit名はつけない u_xxxx 形式が維持されるかどうか不明
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/comments/(\w+)/[^/]*/(\w+)/?$!uo )
            {:site => site ,:type => "comment" , :name => m[2] , :top_comment => m[3] } # part comment
          elsif m = url_o.path.match( %r!^/u(?:ser)?/([\w\-]+)/comments/(\w+)!uo )
            {:site => site ,:type=> "comment" , :name => m[2] }

            ##### ほか
          elsif url_o.path == '/' or url_o.path == ''
            {:site => site , :type => "sub" , :name => "../" , :title => "フロントページ" } # front
          else # 非対応パス
            {:type => "other" , :url => url_o.to_s }
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
      {:type => "other" , :url => url_o.to_s }
    end
  end

  USER_LIST_TITLES = { 
    "" => "コメントと投稿",
    "comments" => "コメント",
    "submitted" => "投稿",
    "upvoted" => "upvoteした投稿",
    "downvoted" => "downvoteした投稿",
    "saved" => "saveした投稿",
    "hidden" => "hideした投稿",
    "gilded" => "goldを贈られたもの",
    "gilded/given" => "goldを贈ったもの",
  }
  def user_list_title( type )
    if t = USER_LIST_TITLES[ type ]
      t
    else
      "no title"
    end
  end

  SUBMISSION_COMMENT_LIST_TITLES = {
    "comments" => "新着コメント",
    "gilded"   => "ゴールドを贈られたもの",
  }
  def submission_comment_list_title( type )
    if t = SUBMISSION_COMMENT_LIST_TITLES[ type ]
      t
    else
      "no title"
    end
  end

end
