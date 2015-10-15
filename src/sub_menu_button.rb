# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'url_handler'
require 'glyph_awesome'

import 'org.controlsfx.control.textfield.TextFields'

class SubMenuButton < Java::JavafxSceneControl::MenuButton
  include JRubyFX::DSLControl

  def menu_from_subname( subs ,name = nil)
    name ||= File.basename(subs)
    url = @uh.subname_to_url( subs )
    menu_from_url( url , name)
  end

  def menu_from_url( url , name , node = nil)
    item = if node
             MenuItem.new(name ,node )
           else
             MenuItem.new( name )
           end
    item.setMnemonicParsing(false)
    page_info = @uh.url_to_page_info( url )
    item.setOnAction{|ev|
      App.i.open_by_page_info( page_info )
    }
    item
  end

  def initialize(site:"reddit" , account_name:nil)
    super("SUBs")
    @site = site
    @account_name = account_name
    @user_menus = []
    @uh = UrlHandler.new(@site)
    @base_menus = []
    @base_menus << menu_from_subname("all")
    @base_menus << menu_from_subname("../","front")
    @base_menus << menu_from_subname("ReddoBrowser")
    @base_menus << SeparatorMenuItem.new
    @base_menus << menu_from_url("https://www.reddit.com/subreddits/" , "webで購読を編集",
                                 GlyphAwesome.make("EDIT"))
    @base_menus << SeparatorMenuItem.new
    
    @multi_menu = Menu.new("マルチレディット")
    @subscribes_menu = Menu.new("購読サブレ")

    # @base_menus << @multi_menu
    # @base_menus << @subscribes_menu

    getItems().setAll( @base_menus )
    load_user_menus
  end

  def set_account_name( name )
    @account_name = name
    load_user_menus
  end

  def load_user_menus
    if @account_name
      if user_subs = App.i.user_subs_hash[ @account_name ]
        set_user_subs_data( user_subs )
        text_field_binding( user_subs )
      else
        getItems().setAll( @base_menus + [MenuItem.new("ロード中…")] )
        App.i.user_subs_hash[@account_name] = UserSubs.new( @account_name ){|us|
          # $stderr.puts "user_subs: #{us}"
          # $stderr.puts "subs: #{us.subscribes}"
          Platform.runLater{
            set_user_subs_data( us )
            text_field_binding( us )
          }
        }
      end
    end
  end # def set_user_menus

  def text_field_binding( user_subs )
    if tf = App.i.root.lookup("#url-text")
      TextFields.bindAutoCompletion( tf , user_subs.subscribes.to_java )
    end
  end

  def set_user_subs_data( user_subs )
    @user_menus = []
    @user_menus << reload_item = MenuItem.new("リロード",GlyphAwesome.make("REFRESH"))
    reload_item.setOnAction{|e|
      App.i.user_subs_hash[ @account_name ] = nil
      load_user_menus
    }
    # @user_menus << SeparatorMenuItem.new
    
    @multi_menu.getItems().setAll( user_subs.multis.map{|m| menu_from_subname( m ) } )
    @subscribes_menu.getItems().setAll( user_subs.subscribes.map{|s|menu_from_subname( s )} )

    @user_menus << @multi_menu
    @user_menus << @subscribes_menu

    getItems().setAll( @base_menus + @user_menus )
  end
end
