# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'pref/account'
require 'app'
require 'util'

require 'sub_page'
require 'rotate_transition_fps_limited'
require 'button_unfocusable'

# require 'tab_hack'
require 'glyph_awesome'

class Page < Java::JavafxSceneLayout::VBox
  include JRubyFX::DSLControl
  
  attr_accessor :page_info

  def prepare_tab(label , icon_res_url_or_im = nil , close_button = true , alt_icon_res_url:nil )
    @pinned = @page_info[:pinned] if @page_info
    # tab
    @tab = Tab.new()
    #tabh = HBox.new()
    @tabh = tabh = BorderPane.new
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

      @pin_iv = ImageView.new( Image.new( App.i.theme::TAB_ICON_PIN ))
      @pin_iv.setFitWidth(16)
      @pin_iv.setFitHeight(16)
      @pin_iv.setPreserveRatio(true)
      
    end

    ### label版
    @tab_label = Label.new( label )
    if Util.is_cjk_text( label )
      # @tab_label.setStyle( "-fx-word-break:break-all;" )
      @tab_style_base = "-fx-word-break:break-all;"
    else
      # @tab_label.setStyle( "-fx-word-wrap:break-word;" )
      @tab_style_base = "-fx-word-wrap:break-word;"
    end
    @tab_style_color = ""
    set_tab_label_style

    @tab_label.setMaxHeight( 48 )
    @tab_label.setAlignment( Pos::CENTER_LEFT )
    @tab_label.setWrapText( true )
    # @tab_label.setText( label )
    set_tab_text( label )
    @tab_label.setPrefWidth( 150 )
    @tab_label.setMaxWidth( 150 )
    @tab_label.setMinWidth( 150 )

    @leftside = Pane.new
    @leftside.setPrefSize( 20 , 38 )
    @leftside.setMinHeight( 48 )
    @tab_number = Label.new("x")
    @tab_number.setStyle("-fx-font-size:85%;")
    # BorderPane.setAlignment( @tab_number , Pos::TOP_LEFT )
    @tab_number.relocate(0,0)
    @leftside.getChildren.add( @tab_number )
    
    if icon_res_url_or_im
      if icon_res_url_or_im.is_a?( String)
        @im_icon = Image.new( App.res( icon_res_url_or_im ),16,16,true,true)
      else
        @im_icon = icon_res_url_or_im
      end
      if alt_icon_res_url
        @im_icon_alt = Image.new( App.res( alt_icon_res_url ),16,16,true,true)
      end
      @im = @im_icon

      @loading_im = Image.new( App.res( '/res/loading.png'), 16 ,16 , true , true)
      @iv = ImageView.new(@im)
      @iv.setPreserveRatio(true)
      @iv.setFitWidth(16)
      @iv.setFitHeight(16)
      # tabh.add( @iv )
      #tabh.setLeft( @iv ) # 多段にする
      # BorderPane.setAlignment( @iv , Pos::CENTER)
      # @leftside.setCenter( @iv )
      @iv.relocate( 1, 16 )
      @leftside.getChildren.add( @iv )
    end

    tabh.setLeft( @leftside )

    # tabh.add( @tab_label )
    # tabh.add( @tab_close_button ) if close_button
    # tabh.setAlignment( Pos::CENTER_LEFT )
    tabh.setCenter( @tab_label )
    BorderPane.setAlignment( @tab_label , Pos::CENTER_LEFT )
    if close_button
      set_close_button_or_pin
    end

    tabh.setMinWidth( 190 ) # 必要
    tabh.setMinHeight( 40 ) # 必要 このへんのサイズとタブ幅の関係で、タブ内のコントールが勝手にblurされてしまう問題
    
    # @tab.setText( label ) ### graphicと同居できない / どうやってメニューに名称を出せばいいのか
    # @tab.set_text_hack( label ) ### 失敗


    ### タブコンテキストメニュー
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
    menu.getItems().add( SeparatorMenuItem.new)

    item_close_other = MenuItem.new("このタブ以外を閉じる")
    item_close_other.setOnAction{|ev|
      App.i.close_pages{|p| (not (p == self)) and not p.pinned }
    }
    menu.getItems().add( item_close_other )
    
    #item_close_comment = MenuItem.new("サブレディット以外を閉じる")
    #item_close_comment.setOnAction{|ev|
    #  App.i.close_pages{|p| not (p.is_a?( SubPage ) and not p.is_user_submission_list) }
    #}
    #menu.getItems().add( item_close_comment )
    
    item_close_all = MenuItem.new("全てのタブを閉じる")
    item_close_all.setOnAction{|ev|
      App.i.close_pages{|p| not p.pinned }
    }
    menu.getItems().add( item_close_all )

    if @page_info and App::TYPE_FOR_SAVE.find{|t| @page_info[:type] == t}
      item_pin = MenuItem.new("Pin/Unpin")
      item_pin.setOnAction{|ev|
        @pinned = (not @pinned)
        @page_info[:pinned] = @pinned if @page_info
        set_close_button_or_pin
      }
      menu.getItems.add( item_pin )
    end
    
    @tab.setContextMenu( menu )

    ### 
    @tab.setGraphic( tabh )
    @tab.setContent( self )
  end

  def set_close_button_or_pin
    if @pinned
      @tabh.setRight( @pin_iv )
      BorderPane.setAlignment( @pin_iv , Pos::CENTER)
    else
      @tabh.setRight( @tab_close_button )
      BorderPane.setAlignment( @tab_close_button , Pos::CENTER)
    end
  end

  def set_pinned( pinned )
    @pinned = pinned
    @page_info[:pinned] = @pinned if @page_info
    set_close_button_or_pin
  end
  attr_reader :pinned

  def set_tab_label_style
    @tab_label.setStyle( @tab_style_base + @tab_style_color )
  end

  def set_tab_label_color(color)
    if color
      @tab_style_color = "-fx-text-fill:#{color};"
    else
      @tab_style_color = ""
    end
    set_tab_label_style
  end

  def set_alt_icon_status( enable )
    if @im_icon_alt
      if enable
        @im = @im_icon_alt
        @iv.setImage( @im ) unless @rt
      else
        @im = @im_icon
        @iv.setImage( @im ) unless @rt
      end
    end
  end

  def set_number(num)
    if num
      @tab_number.setText(num.to_s)
    else
      @tab_number.setText("")
    end
  end

  def close( focus_next = false , save = true)
    Event.fireEvent(@tab, Event.new(Tab::CLOSED_EVENT))
    if focus_next and @tab.isSelected()
      @tab.getTabPane().getSelectionModel().selectNext()
    end
    @tab.getTabPane().getTabs.remove( @tab )
    App.i.save_tabs if save
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
      @rt = nil
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
          err_proc.call(e) if err_proc

        rescue Exception => e
          $stderr.puts e.inspect
          $stderr.puts $@
          err_proc.call(e) if err_proc
        ensure
          Platform.runLater{stop_loading_icon}
          end_proc.call if end_proc
          @loading_thread = nil
        end
      }
    end
  end

  ### thingsのバックグラウンド操作関係
  def set_object_hidden( obj , hidden )
    action = if hidden 
               "hide"
             else
               "unhide"
             end
    App.i.background_network_job( "#{action}しました" ,
                                  "#{action}失敗"){
        cl = App.i.client( @account_name )
        if hidden
          obj.hide
        else
          obj.unhide
        end
        obj[:hidden] = hidden
    }
  end

  def set_object_saved( obj , saved )
    action = if saved
               "save"
             else
               "unsave"
             end
    App.i.background_network_job( "#{action}しました" ,
                                  "#{action}失敗"){
        cl = App.i.client( @account_name )
        if saved
          obj.save
        else
          obj.unsave
        end
        obj[:saved] = saved
    }
  end
  
  def vote( thing , val )
    App.i.background_network_job( "投票しました" , "投票エラー" ){
      c = App.i.client(@account_name) # refresh
      case val
      when true
        thing.upvote
      when false
        thing.downvote
      else
        thing.clear_vote
      end
    }
  end

  ######

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
    @tab_label.setText( Util.cjk_nobreak(text) )
  end

  def on_user_present

  end

  def finish

  end
  
  def on_select
    App.i.set_url_area_text( "" )
  end

  #####

  def key_close
    close(false) if not @pinned
  end

  def key_close_focus_next
    close(true) if not @pinned
  end
end
