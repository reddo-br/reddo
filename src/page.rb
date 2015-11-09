# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'pref/account'
require 'app'

require 'rotate_transition_fps_limited'
require 'button_unfocusable'

# require 'tab_hack'
require 'glyph_awesome'

class Page < Java::JavafxSceneLayout::VBox
  include JRubyFX::DSLControl
  
  attr_accessor :page_info

  def prepare_tab(label , icon_res_url_or_im = nil , close_button = true)
    # tab
    @tab = Tab.new()
    #tabh = HBox.new()
    tabh = BorderPane.new
    if close_button
      close_iv = ImageView.new(Image.new("/res/close.png",16,16,true,true))
      close_iv.setFitWidth(16)
      close_iv.setFitHeight(16)
      close_iv.setPreserveRatio(true)
      # @tab_close_button = Button.new( "" , close_iv)
      @tab_close_button = ButtonUnfocusable.new( "" , close_iv)
      @tab_close_button.setPadding( Insets.new( 1.0 , 1.0 , 1.0 , 1.0 ))
      @tab_close_button.setOnAction{
        # http://stackoverflow.com/questions/17047000/javafx-closing-a-tab-in-tabpane-dynamically
        close( true )
      }
    end

    ### label版
    @tab_label = Label.new( label )
    @tab_label.setStyle( "-fx-word-wrap:break-word ;" )
    @tab_label.setMaxHeight( 48 )
    @tab_label.setAlignment( Pos::CENTER_LEFT )
    @tab_label.setWrapText( true )
    @tab_label.setText( label )
    @tab_label.setPrefWidth( 150 )
    @tab_label.setMaxWidth( 150 )
    @tab_label.setMinWidth( 150 )

    if icon_res_url_or_im
      if icon_res_url_or_im.is_a?( String)
        @im = Image.new( App.res( icon_res_url_or_im ),16,16,true,true)
      else
        @im = icon_res_url_or_im
      end
      @loading_im = Image.new( App.res( '/res/loading.png'), 16 ,16 , true , true)
      @iv = ImageView.new(@im)
      @iv.setPreserveRatio(true)
      @iv.setFitWidth(16)
      @iv.setFitHeight(16)
      # tabh.add( @iv )
      tabh.setLeft( @iv )
      BorderPane.setAlignment( @iv , Pos::CENTER)
    end

    # tabh.add( @tab_label )
    # tabh.add( @tab_close_button ) if close_button
    # tabh.setAlignment( Pos::CENTER_LEFT )
    tabh.setCenter( @tab_label )
    BorderPane.setAlignment( @tab_label , Pos::CENTER_LEFT )
    if close_button
      tabh.setRight( @tab_close_button )
      BorderPane.setAlignment( @tab_close_button , Pos::CENTER)
    end

    tabh.setMinWidth( 190 ) # 必要
    tabh.setMinHeight( 40 ) # 必要 このへんのサイズとタブ幅の関係で、タブ内のコントールが勝手にblurされてしまう問題
    
    # @tab.setText( label ) ### graphicと同居できない / どうやってメニューに名称を出せばいいのか
    # @tab.set_text_hack( label ) ### 失敗


    ### タブ移動メニュー
    menu = ContextMenu.new
    item_up = MenuItem.new("上へ")
    item_up.setOnAction{|ev|
      tab_move( -1 )
    }
    menu.getItems().add( item_up )
    item_down = MenuItem.new("下へ")
    item_down.setOnAction{|ev|
      tab_move( 1 )
    }
    menu.getItems().add( item_down )

    @tab.setContextMenu( menu )

    ### 
    @tab.setGraphic( tabh )
    @tab.setContent( self )
  end

  def close( focus_next = false )
    Event.fireEvent(@tab, Event.new(Tab::CLOSED_EVENT))
    if focus_next and @tab.isSelected()
      @tab.getTabPane().getSelectionModel().selectNext()
    end
    @tab.getTabPane().getTabs.remove( @tab )
    App.i.save_tabs
  end

  def tab_move( move )
    tabs = @tab.getTabPane().getTabs
    index = tabs.find_index{|i| i == @tab}
    selected = @tab.isSelected

    new_pos = (index + move) % tabs.length

    tabs.remove( @tab )
    tabs.add( new_pos , @tab )
    if selected
      @tab.getTabPane().getSelectionModel().select( @tab )
    end
    App.i.save_tabs
  end

  def start_loading_icon
    if @iv
      @iv.setImage( @loading_im )
      @rt = RotateTransitionFPSLimited.new( 8.0 , 5.sec , @iv )
      @rt.setCycleCount(Animation::INDEFINITE )
      @rt.play()
    end
  end

  def stop_loading_icon
    if @rt
      @rt.stop
      @iv.setImage( @im )
    end
  end
  
  def loading( proc , end_proc = nil , err_proc = nil)
    if @loading_thread == nil
      Platform.runLater{start_loading_icon}
      @loading_thread = Thread.new{
        begin
          proc.call
        rescue Redd::Error => e
          $stderr.puts e.inspect
          $stderr.puts $@
          err_proc.call(e.inspect) if err_proc

        rescue Exception => e
          $stderr.puts e.inspect
          $stderr.puts $@
          err_proc.call(e.inspect) if err_proc
        ensure
          Platform.runLater{stop_loading_icon}
          end_proc.call if end_proc
          @loading_thread = nil
        end
      }
    end
  end

  def abort_loading
    if @loading_thread and @loading_thread.alive?
      @loading_thread.kill
      stop_loading_icon
    end
  end

  def tab_widget
    @tab
  end
  
  def set_tab_text( text )
    @tab_label.setText( text )
  end

  def on_user_present

  end

  def finish

  end
  
  #####

  def key_close
    close(false)
  end

  def key_close_focus_next
    close(true)
  end
end
