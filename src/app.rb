# -*- coding: utf-8 -*-

#java.lang.System.setProperty("prism.lcdtext", "true")
#java.lang.System.setProperty("prism.text", "t2k")
#java.lang.System.setProperty("prism.text", "native")
#java.lang.System.setProperty("prism.text", "freetype")

require 'java'

require 'jrubyfx'

require 'redd_patched'
# require 'redd'
require 'client_params'
require 'pref/preferences'
require 'pref/session'
require 'pref/account'
require 'pref/history'

require 'singleton'

require 'mutex_m'

require 'drb_wrapper'

# widget
require 'sub_page'
require 'comment_page'
require 'message_area'
require 'config_page'
require 'google_search_page'

require 'app_toolbar'

require 'read_comment_db'
require 'app_key'

import 'javafx.scene.layout.Region'
import 'javafx.application.Platform'
import 'javafx.scene.input.Clipboard'
import 'javafx.scene.input.ClipboardContent'

class FXApp < JRubyFX::Application
  def start(stage)

    App.i.fxapp = self

    stage.getIcons.addAll( load_app_icons )
    
    with( stage , 
          width:  (App.i.pref['width'] || 1000),
          height: (App.i.pref['height'] || 600),
          title: App::APP_NAME
          ) do
      if App.i.pref["maximized"]
        stage.setMaximized(true)
      end

      layout_scene do
        # root cannot be null

        vbox {
          #tool_bar {
          #  get_items.add user_selector
          #}
          
          at = app_toolbar
          self.class.setMargin( at , Insets.new(3.0 , 3.0 , 3.0 , 3.0))

          tab_pane {|tp|
            tp.setId(App::ID_TAB_PANE)
            tp.setTabMaxHeight( 200 ) 
            tp.setTabMinHeight( 200 ) 
            tp.setTabMaxWidth( 42 )
            tp.setTabMinWidth( 42 )

            setPrefHeight( Region::USE_COMPUTED_SIZE )
            setSide( Side::LEFT )
            setTabClosingPolicy( TabPane::TabClosingPolicy::UNAVAILABLE )

          }
          message_area
        }
      end # scene
      base_font = App.i.pref["fonts"]
      if base_font
        stage.getScene().getRoot().setStyle("-fx-font-family:\"#{base_font}\"")
      end

      App.i.stage = stage
      App.i.scene = stage.getScene()

      AppKey.set_key( App.i.scene ) # key binding

      custom_css = App.res_url("/res/ui.css")
      stage.getScene().getStylesheets().add( custom_css )
      
      if App.i.pref["use_dark_theme"]
        stage.getScene().getStylesheets().add( App.res_url("/res/dark.css") )
      end
      
      # an = App.i.pref["current_account"]
      # App.i.open_by_page_info( type:"sub" , name:"newsokur" , account_name:an )
      # App.i.open_by_page_info( {type:"sub" , name:"../" , account_name:an} , false )
      # App.i.open_by_page_info( {type:"comment" , name:"3gx3l5" , account_name:an} , false )
      # App.i.open_by_page_info( {type:"config" } , false )

      an = App.i.pref["current_account"]
      if not Account.list.find{|a| a == an }
        App.i.pref["current_account"] = nil
      end

      # セッション再生
      # コマンドラインオプションにより、セッションを破棄する
      if $opts.discard_session
        App.i.session.set_page_infos([])
      end

      infos = App.i.session.get_page_infos
      if infos.length > 0
        App.i.session.get_page_infos.each{|pi|
          p pi
          App.i.open_by_page_info( pi , false)
        }
      else
        # 何もなければfrontを開く
        an = App.i.pref["current_account"]
        App.i.open_by_page_info( {type:"sub" , name:"../" , account_name:an} , true )
      end
      
      # コマンドラインのurlを開く
      if url = ARGV.shift
        App.i.open_url( url )
      end
      
      show
      
      stage.setMinWidth( 1000 )
      stage.setMinHeight( 600 )

      # stage.setOnShown{|ev|
      #   $stderr.puts "on shown" # 反応なし
      #   stage.setWidth( stage.getWidth())
      # }

      stage.setOnHiding{|ev|
        $stderr.puts "setOnHiding()"
        if stage.isMaximized
          App.i.pref["maximized"] = true
        else
          App.i.pref["maximized"] = false
          App.i.pref["width"] = stage.getWidth()
          App.i.pref["height"] = stage.getHeight()
        end

        App.i.finish_tabs
      }
      
      if splash = java.awt.SplashScreen.getSplashScreen()
        splash.close()
      end

    end # with

  end

  def load_app_icons
    [ 16 , 32 ,64 , 128 , 256 ,512].map{|size|
      Image.new(App.res( "/res/app_icon.png" ) , size , size , true , true)
    }
  end

end

class App 
  include Singleton
  include ClientParams

  def self.i
    instance
  end

  def self.res( path )
    self.java_class.getResourceAsStream( path )
  end
  def self.res_url( path )
    self.java_class.getResource(path).toExternalForm()
  end
  

  CLIENTS = {}
  def initialize
    @pref = Preferences.new
    @session = Session.new
    @user_subs_hash = {}
    @subs_data_hash = {}
    @close_history = History.new
  end
  attr_reader :pref , :session , :close_history , :theme
  # widget
  attr_accessor :fxapp , :stage , :scene , :user_subs_hash , :subs_data_hash

  def root
    @scene.getRoot()
  end

  def reset_client( name )
    CLIENTS[ name ] = nil
  end

  def client( account_name , force_new = false)
    CLIENTS[ account_name ] = nil if force_new
    CLIENTS[ account_name ] ||= prepare_client( account_name )
    cl = CLIENTS[ account_name ]
    if account_name
      cl.synchronize{
        if cl.access.expired?
          $stderr.puts "トークンをリフレッシュします"
          cl.refresh_access!
          cl.reset_connection # redd_patched faradayの問題？
          if account = Account.byname( account_name )
            json_str = cl.access.to_json
            if json_str.to_s.length > 0 
              account['access_dump'] = json_str
            end
          end
        end
      }
    end
    cl
  end
  alias :cl :client

  def prepare_client( name )
    cl = Redd.it( :web , CLIENT_ID, "" , REDIRECT_URI , user_agent:USER_AGENT )
    cl.extend(Mutex_m)
    if( name )
      account = Account.byname( name )
      if account and account["access_dump"]
        cl.access = Redd::Access.from_json( account["access_dump"] )
        #if cl.access.expired?
        #  cl.refresh_access!
        #end
      end
    end
    cl
  end
  
  def mes(mes , err = false)
    Platform.runLater{
      @scene.lookup("#" + ID_MESSAGE_AREA).set_message(mes)
    }
  end

  def status(mes)
    if mes != "#"
      Platform.runLater{
        @scene.lookup("#" + ID_MESSAGE_AREA).set_status(mes)
      }
    end
  end

  def open_external_browser(url)
    if @pref['browse_alternative_method']
      begin
        java.awt.Desktop.getDesktop().browse(java.net.URI.new(url.to_s))
      rescue
        $stderr.puts $!
        $stderr.puts $@
      end
    else
      if @fxapp
        @fxapp.getHostServices().showDocument(url.to_s)
      end
    end
  end

  def open_by_page_info( page_info , selection = true)
    if page_info[:type] == 'other'
      if page_info[:url].to_s.length > 0
        open_external_browser( page_info[:url] )
      end
    else

      tabpane = @scene.lookup("#" + ID_TAB_PANE)
      target_tab = tabpane.getTabs().find{|tab| 
        page_info_is_same_tab(tab.getContent().page_info , page_info)
      }
      if not target_tab
        target_page = case page_info[:type]
                      when 'comment'
                        CommentPage.new( page_info , start_user_present:selection)
                      when 'sub'
                        SubPage.new( page_info )
                      when 'config'
                        ConfigPage.new(page_info)
                      when 'google_search'
                        GoogleSearchPage.new( page_info )
                      end
        if target_page
          target_tab = target_page.tab_widget
          if @pref['new_tab_after_current']
            cur = tabpane.getSelectionModel.getSelectedIndex || -1
            tabpane.getTabs().add( cur + 1 , target_tab )
          else
            tabpane.getTabs().add( target_tab )
          end
        end
        save_tabs
      else # 既に存在
        if page_info[:type] == 'comment' or page_info[:type] == 'google_search'
          target_tab.getContent().set_new_page_info( page_info )
        end
      end
    
      close_history.remove( page_info )

      if target_tab and selection
        tabpane.getSelectionModel().select( target_tab ) if selection
      end

    end
  end

  def open_url( url , pass_to_external:false , account_name:nil)
    if account_name == nil
      account_name = App.i.pref['current_account']
    end

    uh = UrlHandler.new( account_name:account_name )
    info = uh.url_to_page_info( url )
    if info['type'] == 'other'
      if pass_to_external
        open_external_browser( url )
      end
    else
      App.i.open_by_page_info( info )
    end
    
  end

  def get_info_name_for_compare( info )
    if info[:type] == 'sub'
      info[:name].downcase
    else
      info[:name]
    end
  end

  def page_info_is_same_tab( i1 , i2 )
    name1 = get_info_name_for_compare( i1 )
    name2 = get_info_name_for_compare( i2 )


    i1[:site] == i2[:site] and
      i1[:type] == i2[:type] and
      name1 == name2

  end

  def now
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
  end

  def calc_string_width( string )
    @text_for_width ||= Java::JavafxSceneText::Text.new
    @text_for_width.setText(string)
    @text_for_width.getLayoutBounds().getWidth()
  end

  def set_labeled_min_size( labeled)
    labeled.setMinWidth( calc_string_width( labeled.getText()) )
  end

  def make_pill_buttons( buttons , vertical = false)
    first_class , last_class = if vertical
                                 [ "top-pill" , "bottom-pill" ]
                               else
                                 [ "left-pill" , "right-pill"] 
                               end
    
    buttons.first.getStyleClass().add( first_class)
    buttons.last.getStyleClass().add( last_class)
    
    buttons[1..-2].each{|center| center.getStyleClass().add("center-pill") }

  end

  ID_TAB_PANE = "tab_pane"
  ID_MESSAGE_AREA = "message_area"

  def run

    $drb = DRb.start_service( DrbWrapper::DRB_URI ,
                              DrbWrapper.new( self ))

    ReadCommentDB.instance # ここで初期化しておく

    if pref['use_dark_theme']
      require 'theme/theme_dark'
      @theme = ThemeDark
    else
      require 'theme/theme'
      @theme = Theme
    end

    $thumbnail_plugins = []
    load( 'thumbnail_plugins/imgur.rb' , true )
    load( 'thumbnail_plugins/youtube.rb' , true )
    # todo ユーザーディレクトリからロード

    FXApp.launch
  end

  def finish_tabs
    tabs = []
    tabs += root.lookupAll(".comment-page")
    tabs += root.lookupAll(".sub-page")

    tabs.each{|cp| cp.finish }
    
  end

  def tab_pane
    root.lookup( "#" + ID_TAB_PANE )
  end

  TYPE_FOR_SAVE = [ 'sub' , 'comment' ]
  def save_tabs
    page_infos = tab_pane.getTabs().map{|t| t.getContent().page_info }.find_all{|i| 
      i and TYPE_FOR_SAVE.find{|t| i[:type] == t }
    }
    $stderr.puts "save_tabs:"
    $stderr.puts "#{page_infos}"
    session.set_page_infos( page_infos )
  end

  def active_page
    tab = tab_pane.getSelectionModel().getSelectedItem()
    if tab
      tab.getContent()
    else
      nil
    end
  end

  def copy(str)
    clip = Clipboard.getSystemClipboard()
    content = ClipboardContent.new()
    content.putString( str )
    clip.setContent( content )
  end

  def suppress_printable_key_event( node )
    node.setOnKeyPressed{|ev|
      if is_printable_key_event(ev)
        ev.consume
      end
    }
  end

  def is_printable_key_event( ev )
    not ev.isAltDown and
      not ev.isControlDown and 
      not ev.isMetaDown and
      ev.getText.to_s.length > 0 and 
      ev.getText.ord >= 32 # windowsでは、コントロールコードがこないっぽい
  end

  def adjust_height(  nodes , base = nil)
    if not base
      base = nodes[0]
    end
    nodes.each{|n|
      if n != base
        n.prefHeightProperty.bind( base.heightProperty)
      end
    }
  end

  def close_pages
    tabpane = @scene.lookup("#" + ID_TAB_PANE)
    target_pages = tabpane.getTabs().map{|t| t.getContent() }.find_all{|p| yield(p) }
    target_pages.each{|p|
      p.close( false , false ) # focus_next , save
    }
    save_tabs # ここでまとめて
  end

end
