# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'account_selector'
require 'auth_window'

require 'pref/account'
require 'url_handler'
require 'inbox_button'
require 'sub_menu_button'
require 'user_subs'

# class AppToolbar < Java::JavafxSceneLayout::HBox
class AppToolbar < Java::JavafxSceneLayout::BorderPane
  include JRubyFX::DSLControl

  def initialize
    super()
    # setAlignment( Pos::CENTER_LEFT )
    getStyleClass().add("app-toolbar")

    l_controls = []

    @menu_button = MenuButton.new("Menu")
    l_controls << @menu_button
    menus = []
    menus << menuitem_add = MenuItem.new("アカウント追加" )
    menuitem_add.setOnAction{|ev|
      AuthWindow.new.show()
    }

    menus << menuitem_config = MenuItem.new("設定")
    menuitem_config.setOnAction{|ev|
      App.i.open_by_page_info( {:type => "config" } )
    }

    menus << SeparatorMenuItem.new()

    menus << menuitem_quit = MenuItem.new("終了")
    menuitem_quit.setOnAction{|ev|
      # Platform.exit()
      App.i.stage.close()
    }
    menus << menuitem_quit_notab = MenuItem.new("タブを破棄して終了")
    menuitem_quit_notab.setOnAction{|ev|
      App.i.session.set_page_infos( [] )
      # Platform.exit()
      App.i.stage.close()
    }
    @menu_button.getItems().addAll( menus )

    l_controls << Label.new(" ")

    ld = Label.new("ﾃﾞﾌｫﾙﾄｱｶｳﾝﾄ:")
    App.i.set_labeled_min_size( ld )
    l_controls << ld
    
    @current_account = App.i.pref["current_account"]
    @account_selector = AccountSelector.new( @current_account )
    @account_selector.valueProperty().addListener{|ev|
      ac = @account_selector.get_account
      App.i.pref["current_account"] = ac
      @submenu_button.set_account_name( ac )
    }
    l_controls << @account_selector
    
    l_controls << Label.new(" ")
    l_controls << @submenu_button = SubMenuButton.new( account_name:App.i.pref["current_account"] )

    left = HBox.new
    left.setAlignment( Pos::CENTER_LEFT )
    left.getChildren.setAll( l_controls )
    setLeft( left )

    # l_controls << Label.new(" ")
    
    @url_text = TextField.new()
    @url_text.setId("url-text")
    @url_text.setPromptText("urlか、subreddit名を指定して開きます。\"?キーワード\" でgoogle検索(reddit内)")
    @url_text.setOnKeyPressed{|ev|
      if ev.getCode() == KeyCode::ENTER
        open_text
      elsif ev.getText.to_s.length > 0 and ev.getText.ord >= 32
        ev.consume
      end
    }
    # @url_text.setPrefWidth( 8000 )
    self.class.setMargin( @url_text, Insets.new( 0.0 , 0.0 , 0.0 , 8.0 ))
    setCenter( @url_text )

    # glyph_paste = Glyph.new("FontAwesome", "PASTE").sizeFactor(0.9).color(Color::LIGHTBLUE).useGradientEffect()

    r_controls = []
    r_controls << (@copy_button = Button.new("貼") )
    r_controls << (@open_button = Button.new("開"))
    r_controls << (@clear_button = Button.new("消"))
    @copy_button.setOnAction{|ev|
      clip = Clipboard.getSystemClipboard()
      data = if clip.hasString()
               clip.getString()
             elsif clip.hasUrl()
               clip.getUrl()
             else
               nil
             end
      if data
        @url_text.setText(data)
      end
    }
    @open_button.setOnAction{|ev|
      open_text
    }
    @clear_button.setOnAction{|ev|
      @url_text.setText("")
    }

    ##
    App.i.make_pill_buttons( [ @url_text ] + r_controls )

    r_controls << Label.new(" ")
    r_controls << InboxButton.new

    right = HBox.new
    right.setAlignment( Pos::CENTER_LEFT )
    right.getChildren.setAll( r_controls )
    setRight( right )
    
  end

  def open_text
    text = @url_text.getText().strip
    site = nil

    account_name = @account_selector.get_account
    if account_name
      if ac = Account.byname( account_name )
        site = ac[:site]
      end
    end

    uh = UrlHandler.new( (site || 'reddit') , account_name:account_name)
    
    info = if text[0] == '?'
             word = text[1..-1]
             { :type => "google_search" , :subname => "../" , :word => word , :account_name => account_name }
           elsif text.index('/')
             uh.url_to_page_info( text )
           elsif text == ""
             uh.url_to_page_info( uh.subname_to_url( "../" ))
           else
             uh.url_to_page_info( uh.subname_to_url( text ) )
          end
            
    # p info
    if info[:type] != 'other'
      info[:account_name] = account_name
      App.i.open_by_page_info( info )
    end

  end

  #####

  def key_command
    @url_text.requestFocus
    @url_text.selectRange( 0 , @url_text.getText().length  )
  end

end
