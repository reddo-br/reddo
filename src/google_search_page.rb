# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'page'
require 'url_handler'
require 'uri'
require 'app'
require 'web_view_wrapper'

class GoogleSearchPage < Page
  def initialize( info )
    super(3.0)
    getStyleClass().add("google-search-page")

    @page_info = info
    @subname = info[:subname]
    @word = info[:word]
    @account_name = info[:account_name]
    
    @uh = UrlHandler.new()
    @web_view_wrapper = WebViewWrapper.new{
      # load_search_page
      @web_view_wrapper.set_link_hook
    }

    @web_view_wrapper.webview.setPrefHeight( 10000 )
    @web_view_wrapper.set_worker_running_cb{ 
      # $stderr.puts "search worker running"
      Platform.runLater{start_loading_icon }
    }
    @web_view_wrapper.set_worker_stop_cb{ 
      Platform.runLater{ stop_loading_icon }
    }

    @web_view_wrapper.set_link_cb{|u|
      begin
        base  = URI.parse(@web_view_wrapper.webview.getEngine.location)
        url_o = URI.parse(u)

        target = base.merge( url_o )
        if target.host =~ /^www\.google\./o and target.path == "/url"
          queries = target.query.split(/\&/).map{ |kv| kv.split(/\=/) }
          p queries
          if query_url = queries.assoc( "q" )
            target = URI.parse(URI.decode(query_url[1]))
          end
        end
      
        u = target.to_s
        if u =~ /^https?:\/\/www\.google\.[^\/]+\/search/
          @web_view_wrapper.webview.getEngine.load( u )
        else
          pi = @uh.url_to_page_info( u )
          comment_account = @account_name || Subs.new( @subname )['account_name']
          # $stderr.puts "コメント用アカウント:#{comment_account}"
          pi[:account_name] = comment_account
          App.i.open_by_page_info( pi )
        end
      rescue
        $stderr.puts $!
        $stderr.puts $@
      end
    }
    load_search_page # こっちで
    getChildren.add( @web_view_wrapper.webview )

    prepare_tab( "google検索" ,"/res/search.png" )
  end

  def load_search_page
      # 検索ページへ移動
    $stderr.puts "検索ページ"
    
    url_o = @uh.subname_to_url( @subname )
    $stderr.puts "sub url #{url_o}"
    path = if url_o.path == "/"
             "#{@uh.sub_top}/*/comments"
           else
             url_o.path + "/comments"
           end
    query = "site:#{url_o.host}#{path} #{@word}"
    query_encoded = URI.encode_www_form_component( query )
    search_url = "https://www.google.com/search?hl=ja&q=#{query_encoded}"
    $stderr.puts "検索ページロード #{search_url}"

    @web_view_wrapper.webview.getEngine.load( search_url )

  end

  def set_new_page_info( info )
    @page_info = info
    @subname = info[:subname]
    @word = info[:word]
    @account_name = info[:account_name]

    load_search_page
  end

end
