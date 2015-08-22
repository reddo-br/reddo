# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'redd_patched'
# require 'redd'
require 'client_params'
require 'pref/preferences'
require 'pref/session'

require 'singleton'

require 'mutex_m'

require 'drb_wrapper'

# widget
require 'sub_page'
require 'comment_page'
require 'message_area'
require 'config_page'

require 'app_toolbar'

require 'read_comment_db'
require 'app_key'

import 'javafx.scene.layout.Region'
import 'javafx.application.Platform'

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
      
      # an = App.i.pref["current_account"]
      # App.i.open_by_page_info( type:"sub" , name:"newsokur" , account_name:an )
      # App.i.open_by_page_info( {type:"sub" , name:"../" , account_name:an} , false )
      # App.i.open_by_page_info( {type:"comment" , name:"3gx3l5" , account_name:an} , false )
      # App.i.open_by_page_info( {type:"config" } , false )

      # セッション再生
      infos = App.i.session.get_page_infos
      if infos.length > 0
        App.i.session.get_page_infos.each{|pi|
          p pi
          App.i.open_by_page_info( pi , false)
        }
      else
        an = App.i.pref["current_account"]
        App.i.open_by_page_info( {type:"sub" , name:"../" , account_name:an} , true )
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
  end
  attr_reader :pref , :session
  # widget
  attr_accessor :fxapp , :stage , :scene

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
  
  def mes(mes)
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
    if @fxapp
      @fxapp.getHostServices().showDocument(url.to_s)
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
                      end
        if target_page
          target_tab = target_page.tab_widget
          tabpane.getTabs().add( target_tab )
        end
        save_tabs
      else # 既に存在
        if page_info[:top_comment]
          target_tab.getContent().set_top_comment( page_info[:top_comment] )
        end
      end
    
      if target_tab and selection
        tabpane.getSelectionModel().select( target_tab ) if selection
      end

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

    java.lang.System.setProperty("prism.lcdtext", "false")
    # java.lang.System.setProperty("prism.text", "t2k")
    # java.lang.System.setProperty("prism.text", "native")
    # java.lang.System.setProperty("prism.text", "freetype")

    ReadCommentDB.instance # ここで初期化しておく

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

end
