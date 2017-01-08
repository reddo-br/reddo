# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'app'

require 'comment_page_base'
require 'comment_web_view_wrapper'
require 'url_handler'
require 'edit_widget'
require 'html/html_entity'
require  'read_comment_db'
require 'pref/account'
require 'sub_style'
require 'user_state'

require 'account_selector'
require 'user_ban_state_label'

import 'javafx.application.Platform'
import 'javafx.scene.control.Alert' # jrubyfxにまだない
import 'javafx.scene.control.ButtonType'

class CommentPostListPage < CommentPageBase

  SORT_TYPES = [[ "新着" , "new"],
                [ "トップ" , "top" ],
                [ "論争中","controversial"],
               ]

  def is_valid_sort_type(sort)
    SORT_TYPES.rassoc( sort )
  end

  def initialize( info )
    super(3.0)
    setSpacing(3.0)
    getStyleClass().add("comment-post-list-page")

    @new_comments = []

    @page_info = info
    @page_info[:site] ||= 'reddit'
    @page_info[:type] ||= 'comment-post-list'

    @target_path = @page_info[:name]
    @url_handler = UrlHandler.new( @page_info[:site] )
    @base_url = @url_handler.linkpath_to_url( @target_path )
    @font_zoom = @page_info[:font_zoom] || App.i.pref['comment_page_font_zoom']
    
    @target_user =  @url_handler.path_is_user_comment_list( @target_path ) # ユーザー履歴でなければnil
    owned_target_user = if Account.exist?( @target_user )
                          @target_user
                        else
                          nil
                        end
    # すでに存在しないアカウントの棄却
    if not Account.exist?( @page_info[:account_name] )
      @page_info[:account_name] = nil
    end
    @account_name = owned_target_user || @page_info[:account_name] || App.i.pref['current_account']
    

    queried_sort = if is_valid_sort_type( @page_info[:sort] )
              @page_info[:sort]
            else
              nil
            end
    @default_sort = queried_sort || 'new'

    @split_comment_area = VBox.new

    # @button_area = HBox.new()
    @button_area = BorderPane.new
    # 13@button_area.setAlignment( Pos::CENTER_LEFT )
    # @button_area = ToolBar.new
    @reload_button = Button.new("リロード")
    @reload_button.setOnAction{|e|
      start_reload(asread:false)
    }
    @load_stop_button = Button.new("中断")
    @load_stop_button.setOnAction{|e|
      abort_loading
    }
    

    @sort_selector = ChoiceBox.new
    @sort_selector.getItems().setAll( SORT_TYPES.map{|ta| ta[0] } )
    set_current_sort( @default_sort )

    @sort_selector.valueProperty().addListener{|ov|
      start_reload( asread:false )
      @page_info[:sort] = get_current_sort
      App.i.save_tabs
    }

    @title = info[:title]

        # subのコメントリストでは、ソートは使わない
    if not @target_user
      @sort_selector.setDisable(true)
    end

    # name = @account_name || "なし"
    # @account_label = Label.new("アカウント:" + name)
    @account_selector = AccountSelector.new( @account_name )
    @account_selector.set_change_cb{
      if @account_name != @account_selector.get_account
        @account_name = @account_selector.get_account # 未ログイン = nil
        @comment_view.set_account_name( @account_name )
        App.i.save_tabs
        start_reload
      end
    }

    @user_ban_state_label = UserBanStateLabel.new
    ###
    @comments_menu = MenuButton.new("その他")
    create_others_menu( @comments_menu )
    @context_menu = ContextMenu.new
    create_others_menu( @context_menu )
    ####

    @load_status = Label.new("")
    
    @title_label = Label.new( @title )
    @title_label.setStyle("-fx-font-size:140%")
    button_area_left = HBox.new
    button_area_left.setAlignment( Pos::CENTER_LEFT )
    button_area_left.getChildren.setAll( @account_selector , 
                                         Label.new(" "),
                                         @user_ban_state_label,
                                         Separator.new( Orientation::VERTICAL )
                                         )

    @button_area.setLeft( button_area_left )
    @button_area.setCenter( @title_label )
    @button_area.setRight( @comments_menu )
    [ button_area_left , @title_label , @comments_menu ].each{|e|
      BorderPane.setAlignment( e , Pos::CENTER_LEFT )
    }

    @split_comment_area.getChildren().add( @button_area )
    self.class.setMargin( @button_area , Insets.new( 3.0 , 3.0 , 3.0 , 3.0 ))

    @button_area2 = BorderPane.new()
    # @button_area2.setAlignment( Pos::CENTER_LEFT )
    b_left = HBox.new()
    b_left.setAlignment( Pos::CENTER_LEFT )
    b_left.getChildren().setAll( @reload_button , @load_stop_button , 
                                 Label.new(" ソート:"),
                                 @sort_selector,
                                 Label.new(" "))
    @button_area2.setLeft( b_left )
    @button_area2.setCenter( @load_status )
    BorderPane.setAlignment( @load_status , Pos::CENTER_LEFT )
    @split_comment_area.getChildren().add( @button_area2 )
    self.class.setMargin( @button_area2 , Insets.new( 3.0 , 3.0 , 3.0 , 3.0 ))

    ##########
    btns3 = []
    btns3 << @count_label = Label.new()
    btns3 << Label.new(" ")
    
    find2 = []
    find2 << @find_word_box = TextField.new()
    @find_word_box.setPromptText("検索語")
    @find_word_box.setPrefWidth( 160 )
    find2 << @find_word_clear_button = Button.new("",GlyphAwesome.make("TIMES_CIRCLE"))
    find2 << @find_word_r_button = Button.new("",GlyphAwesome.make("CHEVRON_LEFT"))
    find2 << @find_word_button = Button.new("",GlyphAwesome.make("CHEVRON_RIGHT"))
    App.i.make_pill_buttons( find2 )
    btns3 += find2
    btns3 << Label.new(" ")
    btns3 << @find_word_count = Label.new()
    
    App.i.adjust_height( find2 , @find_word_box )

    @find_word_box.textProperty().addListener{|ev|
      Platform.runLater{
        highlight_word()
      }
    }
    @find_word_box.setOnKeyPressed{|ev|
      if ev.getCode() == KeyCode::ENTER
        Platform.runLater{@comment_view.scroll_to_highlight(true)}
      elsif App.i.is_printable_key_event(ev)
        ev.consume
      end
    }
    @find_word_clear_button.setOnAction{|ev| @find_word_box.setText("") }
    @find_word_button.setOnAction{|ev| 
      Platform.runLater{@comment_view.scroll_to_highlight( true ) }
    }
    @find_word_r_button.setOnAction{|ev| 
      Platform.runLater{@comment_view.scroll_to_highlight( false ) }
    }

    @button_area3 = HBox.new()
    @button_area3.setAlignment( Pos::CENTER_LEFT )
    @button_area3.getChildren().setAll( btns3 )
    @split_comment_area.getChildren().add( @button_area3 )
    self.class.setMargin( @button_area3 , Insets.new( 3.0 , 3.0 , 3.0 , 3.0 ))

    ##########
    @comment_view = CommentWebViewWrapper.new{
      # @comment_view.set_title(@title)
      @comment_view.set_comment_post_list_mode( true )
      @comment_view.set_font_zoom( @font_zoom )
      start_reload( asread:false ) # todo: postデータが無いときのみ trueにする
    }
    # @Comment_view.set_title("test")
    @comment_view.webview.setPrefHeight( 10000 )
    @comment_view.set_account_name( @account_name ) # editの判定にclient.meは時間かかる
    @comment_view.set_url_handler( @url_handler )

    @comment_view.set_vote_cb{|thing , val|
      vote( thing , val )
    }

    @comment_view.set_link_cb{|link, shift |
      page_info = @url_handler.url_to_page_info( link )
      page_info[:account_name] = @account_name
      App.i.open_by_page_info( page_info , (not shift))
    }

    # @comment_view.set_reply_cb{|obj|
    #   open_edit_area
      
    #   @replying = obj
    #   @editing  = nil

    #   @split_edit_area.set_text( "" , mode:"reply" )

    #   highlight_replying
    # }

    @comment_view.set_edit_cb{|obj|
      open_edit_area
      
      @replying = nil
      @editing  = obj

      md_html_encoded = obj[:body] || obj[:selftext]
      md = Html_entity.decode( md_html_encoded.to_s )
      @split_edit_area.set_text( md , mode:"edit" )
      
      highlight_replying

    }

    @comment_view.set_delete_cb{| obj, has_children |
      # dialog
      dialog = Alert.new( Alert::AlertType::CONFIRMATION , 
                          "")
      dialog.initModality( Modality::APPLICATION_MODAL )
      dialog.initOwner( App.i.stage )
      dialog.getDialogPane.setContentText( "投稿/コメントを削除します")
      dialog.getDialogPane.setHeaderText(nil)

      op = dialog.showAndWait() # .filter{|r| r == ButtonType::OK}
      if op.isPresent and op.get == ButtonType::OK
        loading( Proc.new{ delete( obj , show_delete_element:has_children) } ,
                 Proc.new{
                   Platform.runLater{
                     set_load_button_enable( true )
                   }
                 },
                 Proc.new{|e|
                   App.i.mes("削除エラー")
                 }
                 )
      end
    }

    @comment_view.set_hide_cb{|obj, hide |
      set_object_hidden( obj , hide )
    }
    @comment_view.set_save_cb{|obj, save |
      set_object_saved( obj , save )
    }
    @comment_view.custom_menu = @context_menu

    @split_comment_area.getChildren().add( @comment_view.webview )
    
    @split_edit_area = EditWidget.new( account_name:@account_name ,
                                       site:@site ) # リンク生成用
    @split_edit_area.setVisible(false)
    @split_edit_area.set_close_cb{
      @split_edit_area.set_error_message("")
      close_edit_area
    }
    @split_edit_area.set_post_cb{ |md_text|
      end_proc = Proc.new{
        set_load_button_enable( true )
        Platform.runLater{
          @split_edit_area.set_now_loading(false)
        }
      }
      
      error_proc = Proc.new {|e|
        if e.is_a?( Redd::Error::RateLimited )
          Platform.runLater{
            @split_edit_area.set_error_message("#{App.i.now} 投稿エラー 投稿間隔制限 あと#{e.time.to_i}秒")
          }
        else
          Platform.runLater{
            @split_edit_area.set_error_message("#{App.i.now} 投稿エラー #{e}")
          }
        end
      }
      
      if @replying
        # $stderr.puts "reply to #{@replying[:name]}"
        # $stderr.puts md_text
        # ここで投稿
        loading( Proc.new{ post( @replying , md_text ) } ,
                 end_proc ,
                 error_proc)

      elsif @editing
        loading( Proc.new{ edit( @editing , md_text ) } ,
                 end_proc ,
                 error_proc)
      end
      
    } # set_post_cb
    
    @comment_view.set_more_cb{|more , elem_id |
      start_reload( asread:false , add:true , more_button_id:elem_id )
    }

    @split_pane = SplitPane.new
    @split_pane.setOrientation( Orientation::VERTICAL )
    # @split_pane.getItems().setAll( @split_comment_area , @split_edit_area )
    @split_pane.getItems().setAll( @split_comment_area )
    @split_pane.setDividerPositions( 0.5 )
    
    getChildren().add( @split_pane )

    icon = if @target_user
             App.i.theme::TAB_ICON_USER
           else
             App.i.theme::TAB_ICON_COMMENT2
           end
    prepare_tab( @title , icon )
    # Page
    @tab.setOnClosed{|ev|
      # ここはタブを明示的に閉じたときしか来ない
      $stderr.puts "comment_page onclose"
      finish()
      App.i.close_history.add( @page_info , @title )
    }

  end # initialize
  
  def create_others_menu(menu)
    external_browser_item = MenuItem.new("webで開く")
    external_browser_item.setOnAction{|e|
      if url = make_page_url
        App.i.open_external_browser( url )
      end
    }
    menu.getItems.add( external_browser_item )
    
    copy_url_item = MenuItem.new("URLをコピー")
    copy_url_item.setOnAction{|e|
      if url = make_page_url
        App.i.copy( url )
      end
    }
    menu.getItems.add( copy_url_item )

    menu.getItems.add( SeparatorMenuItem.new )
    zoom_menu , zoom_menu_refresh_cb = make_zoom_button_menu
    menu.getItems.add( zoom_menu )

    if @target_user
      set_user_history_menuitems(menu)
    end

    if menu.respond_to?(:setOnShowing)
      menu.setOnShowing{|ev|
        zoom_menu_refresh_cb.call
      }
    else
      menu.setOnMouseClicked{|ev|
        zoom_menu_refresh_cb.call
      }
    end

    menu
  end

  def create_title
    username , type = App.i.path_to_user_history( @target_path )
    if username and type
      @target_user = username
      "#{type[0]} [#{username}]"
    else
      @target_path
    end
  end

  def make_page_url
    if @base_url
      comment_link = @base_url.to_s
      sort = get_current_sort
      if sort != @default_sort
        comment_link += ( "?sort=" + sort )
      end
      comment_link
    else
      nil
    end
  end

  def focus_editarea_if_opened
    if @split_pane.getItems().length > 1
      @split_edit_area.focus_input
    end
  end

  def get_current_sort
    SORT_TYPES.assoc(@sort_selector.getSelectionModel.getSelectedItem)[1]
  end

  def set_current_sort(sort)
    @sort_selector.getSelectionModel.select( SORT_TYPES.rassoc(sort)[0] )
  end

  def highlight_replying( move:true )
    if @editing
      @comment_view.set_replying( @editing[:name] , mode:"edit" , move:move)
    elsif @replying
      @comment_view.set_replying( @replying[:name] , mode:"reply" , move:move)
    end
  end

  def highlight_word()
    @comment_view.highlight( @find_word_box.getText().strip )
    cnt = @comment_view.current_highlight_poses.length
    if cnt == 0
      @find_word_count.setText("")
    else
      @find_word_count.setText("#{cnt} 件")
    end
  end

  def finish
    # @comment_view.webview.getEngine().load("about:blank") # メモリーリーク対策 ← しかし不安定化する
  end

  def set_load_button_enable( enable )
    start_buttons = [ @reload_button , # @split_edit_area.post_button , 
                      @account_selector]
    if @target_user
      start_buttons << @sort_selector
    end
    stop_buttons  = [ @load_stop_button ]

    set_load_button_enable2( enable , start_buttons , stop_buttons )
  end

  # webivewとスレッド
  # http://stackoverflow.com/questions/20225264/understanding-the-javafx-webview-threading-model
  
  def start_reload( asread:false , add:false , more_button_id:nil)
    loading( Proc.new{ 
               if not add
                 force_comment_clear
                 @comments = []
               end
               reload(asread:asread , add:add)
               if more_button_id
                 Platform.runLater{ @comment_view.more_result( more_button_id , true ) }
               end
               Platform.runLater{ @split_edit_area.set_comment_error(false) }
             } , 
             Proc.new{ 
               set_load_button_enable( true )
               Platform.runLater{ @split_edit_area.set_now_loading(false) }
             } ,
             Proc.new{ |e|
               # App.i.mes("#{@title} 更新失敗")
               set_status("#{App.i.now} エラー #{e}" , true)
               if more_button_id
                 Platform.runLater{@comment_view.more_result(more_button_id , false)}
               end
               Platform.runLater{ @split_edit_area.set_comment_error(true) }
               $stderr.puts e.inspect
               $stderr.puts e.backtrace
             }
             )
    
    
  end

  def set_user_history_menuitems(menu)
    # @user_history_separator ||= SeparatorMenuItem.new
    # items = menu.getItems
    # if (i = items.indexOf(@user_history_separator)) >= 0
    #   subs = items.subList( i + 1 , items.size() )
    #   subs.clear
    #   subs.addAll( App.i.make_user_history_menuitems( @target_user ))
    # else
    #   menu.getItems.add( @user_history_separator )
    #   menu.getItems.addAll( App.i.make_user_history_menuitems( @target_user ))
    # end

    menu.getItems.add( SeparatorMenuItem.new )
    menu.getItems.addAll( App.i.make_user_history_menuitems( @target_user ))

  end

  # def check_read
  #   ReadCommentDB.instance.add( @new_comments.map{|o| o[:name] } )
  #   @new_comments = []
  #   show_num_new_comments
  # end

  # def check_read2
  #   ReadCommentDB.instance.add( @new_comments.map{|o| o[:name] } )
  #   ReadCommentDB.instance.set_count( @link_id , @num_comments ) 
  #   Platform.runLater{
  #     # show_num_comments
  #     notify_comment_fetched
  #   }
  # end

  # def on_user_present
  #   if not @shown_to_user
  #     check_read2
  #     Platform.runLater{
  #       set_tab_text( @title )
  #     }
  #     @shown_to_user = true
  #   end
  # end

  def force_comment_clear
    begin
      Util.explicit_clear( @comments )
      # Util.explicit_clear( @links )
    rescue
      $stderr.puts "コメントデータの明示的消去に失敗"
    end
  end

  COMMENT_FETCH_LIMIT = 50
  def reload( asread:false , add:false )
    set_load_button_enable( false )
    Platform.runLater{@split_edit_area.set_now_loading( true )}
    set_status( "更新中…" , false , true)

    if @account_name and @target_user and not (Account.byname( @account_name ).scopes.index("history"))
      Platform.runLater{@comment_view.set_message("注意：ユーザーの履歴表示には、新規の権限が必要です。旧バージョンで認可を与えたアカウントは、再度「アカウント追加」で認可を与える必要があります。")}
    else
      Platform.runLater{@comment_view.set_message(nil)}
    end

    # submission#get では、コメントが深いレベルまでオブジェクト化されない問題
    ut = Thread.new{
      @user_state = UserState.from_username( @account_name )
      @user_state.refresh
    }

    sort_type = get_current_sort

    cl = App.i.client( @account_name )
    target_user_info = nil
    if @target_user
      ut2 = Thread.new{
        target_user_info = cl.user_from_name( @target_user )
      }
    end
    after = if @comments.length > 0
              @comments.last[:name]
            else
              nil
            end
    comments_raw = cl.get( "#{@target_path}.json" , limit:COMMENT_FETCH_LIMIT , 
                           sort:sort_type , after:after).body

    # force_comment_clear
    comment_fetched = object_to_deep( comments_raw )
    comment_fetched.each{|c| mark_to_ignore(c) }
    @comments += comment_fetched

    @comment_view.set_base_url( @base_url )

    ut.join
    if @user_state and @user_state.user
      @comment_view.set_user_suspended( @user_state.user[:is_suspended] )
    end
    
    ut2.join if @target_user
    Platform.runLater{
      @user_ban_state_label.set_data( @user_state.user , @user_state.is_shadowbanned) if @user_state
      @comment_view.clear_comment if not add
      # @comment_view.set_title( title ) # if @comment_view.dom_prepared

      if target_user_info
        @comment_view.set_user_info(target_user_info)
      end

      comment_fetched.each{|c| @comment_view.add_comment( c ) }
      @comment_view.line_image_resize( @font_zoom )
      # puts @comment_view.dump
      if comment_fetched.length >= COMMENT_FETCH_LIMIT
        @comment_view.add_list_more_button
      end

      @comment_view.set_link_hook

      set_status(App.i.now + " 更新")
      highlight_word()
      highlight_replying(move:false)
    }
  end

  #####


end
