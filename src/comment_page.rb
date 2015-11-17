# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'app'

require 'page'
require 'comment_web_view_wrapper'
require 'url_handler'
require 'edit_widget'
require 'html/html_entity'
require  'read_comment_db'
require 'pref/account'
require 'sub_style'

require 'account_selector'

import 'javafx.application.Platform'
import 'javafx.scene.control.Alert' # jrubyfxにまだない
import 'javafx.scene.control.ButtonType'

class CommentPage < Page

  SORT_TYPES = [[ "新着" , "new"],
                [ "古い順" , "old" ],
                # [ "注目" , "hot" ],
                [ "トップ" , "top" ],
                [ "ベスト","confidence"], # いわゆるbest
                [ "論争中","controversial"],
                # [ "ランダム","random"],
                [ "Q&A","qa"]
               ]

  def is_valid_sort_type(sort)
    SORT_TYPES.rassoc( sort )
  end

  def initialize( info , start_user_present:true)
    super(3.0)
    setSpacing(3.0)
    getStyleClass().add("comment-page")

    @new_comments = []

    @page_info = info
    @page_info[:site] ||= 'reddit'
    @page_info[:type] ||= 'comment'

    @link_id = @page_info[:name] # commentではid not fullname
    @top_comment = @page_info[:top_comment] # todo: 単独コメント機能
    @comment_context = @page_info[:context]
    @url_handler = UrlHandler.new( @page_info[:site] )

    # すでに存在しないアカウントの棄却
    if not Account.exist?( @page_info[:account_name] )
      @page_info[:account_name] = nil
    end
    rec_account = ReadCommentDB.instance.get_subm_account(@link_id)
    if not Account.exist?( rec_account )
      ReadCommentDB.instance.get_subm_account(nil)
    end

    if rec_account == false
      @account_name = nil
    else
      @account_name = rec_account || @page_info[:account_name]
      ReadCommentDB.instance.set_subm_account( @link_id , @account_name )
    end
    # @site = site
    queried_sort = if is_valid_sort_type( @page_info[:sort] )
              @page_info[:sort]
            else
              nil
            end
    @default_sort = queried_sort || @page_info[:suggested_sort] || 'new'

    @split_comment_area = VBox.new

    @shown_to_user = true

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
    
    @autoreload_check = CheckBox.new()
    @autoreload_check.setTooltip(Tooltip.new("約5分ごとに自動で更新します"))
    enable_autoreload = if @page_info[:autoreload] == 'on'
                          true
                        elsif @page_info[:autoreload] == 'off'
                          false
                        else
                          App.i.pref['enable_autoreload']
                        end

    if enable_autoreload
      @autoreload_check.setSelected(true) # 初回のautoreload始動はinitialize内でやる
    end
    @autoreload_check.selectedProperty().addListener{|ev|
      if ev.getValue
        @page_info[:autoreload] = 'on'
      else
        @page_info[:autoreload] = 'off'
      end
      App.i.save_tabs
      control_autoreload
    }

    @autoreload_status = Label.new("準備中")
    @autoreload_status.setStyle("-fx-background-color:#{App.i.theme::COLOR::HTML_TEXT_THIN};-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};")

    @sort_selector = ChoiceBox.new
    @sort_selector.getItems().setAll( SORT_TYPES.map{|ta| ta[0] } )
    set_current_sort( @default_sort )

    @sort_selector.valueProperty().addListener{|ov|
      start_reload( asread:false )
      @page_info[:sort] = get_current_sort
      App.i.save_tabs
    }

    @title = @page_info[:title] # 暫定タイトル / これはデコードされてる
    
    # name = @account_name || "なし"
    # @account_label = Label.new("アカウント:" + name)
    @account_selector = AccountSelector.new( @account_name )
    @account_selector.set_change_cb{
      if @account_name != @account_selector.get_account
        @account_name = @account_selector.get_account # 未ログイン = nil
        @comment_view.set_account_name( @account_name )
        if @account_name
          ReadCommentDB.instance.set_subm_account( @link_id , @account_name )
          @page_info[:account_name] = @account_name
        else
          ReadCommentDB.instance.set_subm_account( @link_id , false ) # 明示的な未ログイン
          @page_info[:account_name] = false
        end
        App.i.save_tabs
        start_reload
      end
    }
    
    ###
    @comments_menu = MenuButton.new("その他")

    external_browser_item = MenuItem.new("webで開く")
    external_browser_item.setOnAction{|e|
      if url = make_page_url
        App.i.open_external_browser( url )
      end
    }
    @comments_menu.getItems.add( external_browser_item )
    
    copy_url_item = MenuItem.new("URLをコピー")
    copy_url_item.setOnAction{|e|
      if url = make_page_url
        App.i.copy( url )
      end
    }
    @comments_menu.getItems.add( copy_url_item )

    copy_url_item_short = MenuItem.new("URLをコピー(短縮)")
    copy_url_item_short.setOnAction{|e|
      App.i.copy( "https://redd.it/#{@page_info[:name]}" )
    }
    @comments_menu.getItems.add( copy_url_item_short )

    ####

    @load_status = Label.new("")
    
    @subname_label = Label.new("")

    @title_label = Label.new( @title )
    @title_label.setStyle("-fx-font-size:14pt")
    button_area_left = HBox.new
    button_area_left.setAlignment( Pos::CENTER_LEFT )
    button_area_left.getChildren.setAll( @account_selector , 
                                         Label.new(" "),
                                         @subname_label ,
                                         Separator.new( Orientation::VERTICAL ),
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
                                 Label.new(" "),
                                 @autoreload_check,
                                 @autoreload_status,
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
    btns3 << @count_new_label = Label.new()
    find1 = []
    #find1 << @find_new_r_button = Button.new("◀")
    #find1 << @find_new_button = Button.new("▶")
    find1 << @find_new_r_button = Button.new("",GlyphAwesome.make("CHEVRON_LEFT"))
    find1 << @find_new_button = Button.new("",GlyphAwesome.make("CHEVRON_RIGHT"))
    App.i.make_pill_buttons( find1 )
    btns3 += find1
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
    
    # awesome 高さ揃え
    #[ @find_new_r_button, @find_new_button, 
    #  @find_word_r_button, @find_word_button , @find_word_clear_button].each{|b|
    #  b.prefHeightProperty.bind( @find_word_box.heightProperty )
    #}
    App.i.adjust_height( find1 + find2 , @find_word_box )

    @find_new_button.setOnAction{|ev| 
      Platform.runLater{scroll_to_new( true ) }
    }
    @find_new_r_button.setOnAction{|ev| 
      Platform.runLater{scroll_to_new( false ) }
    }

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

    @button_area4 = HBox.new()
    @button_area4.setAlignment( Pos::CENTER_LEFT )
    partial_comment_label = Label.new("一部のコメントを表示しています ")
    partial_comment_label.setStyle("-fx-text-fill:red;")
    @button_area4.getChildren().add( partial_comment_label )
    @clear_partial_thread_button = Button.new( "全体を表示する")
    @clear_partial_thread_button.setOnAction{|ev|
      @top_comment = nil
      show_single_thread_bar( false )
      start_reload( asread:false )
      @page_info[:top_comment] = nil
      @page_info[:context] = nil
      App.i.save_tabs
    }
    @button_area4.getChildren().add( @clear_partial_thread_button )
    self.class.setMargin( @button_area4 , Insets.new( 3.0 , 3.0 , 3.0 , 3.0 ))
    if @top_comment
      @split_comment_area.getChildren().add( @button_area4 )
    end

    @num_comments = 0
    show_num_comments
    show_num_new_comments

    ##########
    @comment_view = CommentWebViewWrapper.new{
      # @comment_view.set_title(@title)
      check_read = if ReadCommentDB.instance.get_count( @link_id )
                     false
                   else
                     true
                   end

      start_reload( asread:check_read , user_present:start_user_present) # todo: postデータが無いときのみ trueにする
    }
    # @Comment_view.set_title("test")
    @comment_view.webview.setPrefHeight( 10000 )
    @comment_view.set_account_name( @account_name ) # editの判定にclient.meは時間かかる
    @comment_view.set_url_handler( @url_handler )

    @comment_view.set_vote_cb{|thing , val|
      Thread.new{
        begin
          c = App.i.client(@account_name) # refresh
          case val
          when true
            thing.upvote
          when false
            thing.downvote
          else
            thing.clear_vote
          end
          App.i.mes("投票しました")
        rescue Redd::Error => e
          $stderr.puts $!
          $stderr.puts $@
          App.i.mes("投票エラー #{e.inspect}")
        rescue
          $stderr.puts $!
          $stderr.puts $@
          App.i.mes("投票エラー")
        end
      }
    }

    @comment_view.set_link_cb{|link, shift |
      page_info = @url_handler.url_to_page_info( link )
      page_info[:account_name] = @account_name
      App.i.open_by_page_info( page_info , (not shift))
    }

    @comment_view.set_reply_cb{|obj|
      resized = false
      if @split_pane.getItems().size == 1
        @split_edit_area.setVisible(true)
        @split_pane.getItems().add( @split_edit_area )
        resized = true
      end

      @replying = obj
      @editing  = nil

      @split_edit_area.set_text( "" , mode:"reply" )

      highlight_replying
    }

    @comment_view.set_edit_cb{|obj|
      resized = false
      if @split_pane.getItems().size == 1
        @split_edit_area.setVisible(true)
        @split_pane.getItems().add( @split_edit_area )
        resized = true
      end

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

    @split_comment_area.getChildren().add( @comment_view.webview )
    
    @split_edit_area = EditWidget.new( account_name:@account_name ,
                                       site:@site ) # リンク生成用
    @split_edit_area.set_close_cb{
      @split_edit_area.set_error_message("")
      close_edit_area
    }
    @split_edit_area.set_post_cb{ |md_text|
      if @replying
        # $stderr.puts "reply to #{@replying[:name]}"
        # $stderr.puts md_text
        # ここで投稿
        loading( Proc.new{ post( @replying , md_text ) } ,
                 Proc.new{
                   Platform.runLater{
                     set_load_button_enable( true )
                     #close_edit_area
                     # @replying = nil
                   }
                 },
                 Proc.new {|e|
                   # $stderr.puts "投稿エラー"
                   if e.class == Redd::Error::RateLimited 
                     # App.i.mes("投稿エラー 投稿間隔が制限されています")
                     Platform.runLater{
                       @split_edit_area.set_error_message("#{App.i.now} 投稿エラー 投稿間隔が制限されています")
                     }
                   else
                     # App.i.mes("投稿エラー")
                     Platform.runLater{
                       @split_edit_area.set_error_message("#{App.i.now} 投稿エラー #{e}")
                     }
                   end
                 }
                 )

      elsif @editing
        loading( Proc.new{ edit( @editing , md_text ) } ,
                 Proc.new{
                   Platform.runLater{
                     set_load_button_enable( true )
                     #close_edit_area
                     # @editing = nil
                   }
                 },
                 Proc.new {|e|
                   if e.class == Redd::Error::RateLimited 
                     # App.i.mes("編集エラー 投稿間隔が制限されています")
                     Platform.runLater{
                       @split_edit_area.set_error_message("#{App.i.now} 編集エラー 投稿間隔が制限されています")
                     }
                   else
                     # App.i.mes("編集エラー")
                     Platform.runLater{
                       @split_edit_area.set_error_message("#{App.i.now} 編集エラー #{e}")
                     }
                   end
                 }
                 )
      end
      
    }

    @comment_view.set_more_cb{|more , elem_id |

      if @links and @links[0]
        subm = @links[0]
        Thread.new{
          begin
            # todo: アカウントが無い場合、通常のget_commentを使って取得する
            cl = App.i.client( @account_name )
            list = subm.expand_more_hack( more , sort:"new")
            
            list = object_to_deep( list )

            added = []
            comments_each(list){|c| 
              added << c[:name] if c[:name]
            }
            ReadCommentDB.instance.add( added )

            Platform.runLater{
              stop_autoreload
              @comment_view.more_result( elem_id , true ) # moreボタンを消す
              list.each{|c| 
                @comment_view.add_comment(c , more.parent_id ) 
                @comment_view.set_link_hook
                highlight_word()
              }
            } # runLater
            
          rescue
            $stderr.puts $!
            $stderr.puts $@
            Platform.runLater{
              @comment_view.more_result( elem_id , false )
            }
          end
        }
      else
        @comment_view.more_result( elem_id , false )
      end
    }

    # @split_edit_area =  TextArea.new()
    
    @split_pane = SplitPane.new
    @split_pane.setOrientation( Orientation::VERTICAL )
    # @split_pane.getItems().setAll( @split_comment_area , @split_edit_area )
    @split_pane.getItems().setAll( @split_comment_area )
    @split_pane.setDividerPositions( 0.5 )
    
    getChildren().add( @split_pane )

    prepare_tab( @title || "取得中" , App.i.theme::TAB_ICON_COMMENT )
    
    # Page
    @tab.setOnClosed{|ev|
      # ここはタブを明示的に閉じたときしか来ない
      $stderr.puts "comment_page onclose"
      # check_read()
      check_read2()
      finish()
      App.i.close_history.add( @page_info , @title )
    }
    @tab.setOnSelectionChanged{|ev|
      if @tab.isSelected()
        # 
        # $stderr.puts "#{@title} selected"
      else
        # $stderr.puts "#{@title} unselected"
      end
      on_user_present
    }

    #setOnMouseClicked{|ev|
    #  $stderr.puts "clicked - seems user present "
    #  on_user_present
    #}
    @comment_view.webview.setOnScroll{|ev|
      on_user_present
    }

    # control_autoreload # start_reload内から呼ばないと@comment_numが判断できない
    

  end # initialize
  
  def make_page_url
    if @base_url
      comment_link = @base_url.to_s
      if @top_comment
        comment_link += @top_comment
      end
      sort = get_current_sort
      if sort != @default_sort
        comment_link += ( "?sort=" + sort )
      end
      comment_link
    else
      nil
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

  def start_autoreload
    if not @autoreload_thread
      @autoreload_thread = Thread.new{
        target_interval = 300
        interval = target_interval + 5 + rand(15)
        loop {
          begin
            $stderr.puts "autoreload sleep #{interval} sec"
            sleep( interval )
            $stderr.puts "autoreload thread loop #{@title} #{Time.now}"
            if @last_reload and (@last_reload + target_interval ) < Time.now
              start_reload( user_present:false )
              interval = target_interval + rand(15)
            else
              interval = (@last_reload + target_interval ) - Time.now
              interval = 1 if interval < 1
            end
          rescue
            $stderr.puts "autoreloadエラー #{@title} #{Time.now}"
            $stderr.puts $!
            $stderr.puts $@
          end
        }
      }
      
      Platform.runLater{
        @autoreload_status.setText("自動更新中")
        @autoreload_status.setStyle("-fx-background-color:#{App.i.theme::COLOR::STRONG_GREEN};-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};")
      }
    end
  end

  def stop_autoreload
    begin
      if @autoreload_thread
        #if @autoreload_thread.alive?
          @autoreload_thread.kill
        #end
        @autoreload_thread = nil
      end
    rescue
      $stderr.puts "Thread kill error"
      $stderr.puts $!
      $stderr.puts $@
    end
    Platform.runLater{
        @autoreload_status.setText("自動更新中断")
      @autoreload_status.setStyle("-fx-background-color:#{App.i.theme::COLOR::STRONG_YELLOW};-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};")
    }
  end

  def disable_autoreload
    begin
      if @autoreload_thread
        #if @autoreload_thread.alive?
          @autoreload_thread.kill
        #end
        @autoreload_thread = nil
      end
    rescue
      $stderr.puts "Thread kill error"
      $stderr.puts $!
      $stderr.puts $@
    end
    Platform.runLater{
        @autoreload_status.setText("自動更新無効")
        @autoreload_status.setStyle("-fx-background-color:#{App.i.theme::COLOR::STRONG_RED};-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};")
    }
  end

  def set_top_comment( top_comment_id , context = nil)
    @top_comment = top_comment_id
    @comment_context = context
    show_single_thread_bar( true )
    start_reload( asread:false )
    @page_info[:top_comment] = @top_comment
    @page_info[:context] = @comment_context
  end

  def set_new_page_info( info )
    # 上書きできるのは、top_commentとsortだけにしとく
    # p info
    # p @top_comment
    # p @comment_context
    changed = ( (@top_comment != info[:top_comment]) or (@comment_context != info[:context] ) )
    if changed
      @top_comment = info[:top_comment]
      @comment_context = info[:context]
      if @top_comment
        show_single_thread_bar( true )
      else
        show_single_thread_bar( false )
      end
    end
    
    if info[:sort] and is_valid_sort_type( info[:sort] )
      current_sort = get_current_sort
      if current_sort != info[:sort]
        set_current_sort( info[:sort] ) # listenerでリロードさせる
      else
        start_reload( asread:false ) if changed
      end
    else
      start_reload( asread:false ) if changed
    end
  end

  def show_single_thread_bar( show = true )
    if show
      # @split_comment_area.getChildren().subList(0,3).add( @button_area4 )
      children = @split_comment_area.getChildren()
      if children.indexOf( @button_area4 ) == -1
        children.add( 3 , @button_area4 )
      end
    else
      @split_comment_area.getChildren().remove( @button_area4 )
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
    stop_autoreload
    # @comment_view.webview.getEngine().load("about:blank") # メモリーリーク対策 ← しかし不安定化する
  end

  def scroll_to_new( forward )
    if @new_comments.length > 0
      new_comment_poses = @new_comments.map{|o| @comment_view.id_to_pos( o[:name] ) }
      @comment_view.scroll_to_next_position( forward , new_comment_poses )
    end
  end

  def show_num_comments
    @count_label.setText("コメント#{@num_comments}件")
  end
  def show_num_new_comments
    num = @new_comments.length
    @count_new_label.setText("新着#{num}件")
    if num > 0
      @find_new_button.setDisable( false )
      @find_new_r_button.setDisable( false )
    else
      @find_new_button.setDisable( true )
      @find_new_r_button.setDisable( true )
    end
  end

  def close_edit_area
    @split_edit_area.setVisible( false )
    @split_pane.getItems().remove( 1 , 2 )
    
    target = @replying || @editing
    if target
      @comment_view.clear_replying( target[:name] )
    end
    @replying = @editing = nil
  end

  class OneshotChangeListener
    include javafx.beans.value.ChangeListener
    def initialize( property , &cb )
      @cb = cb
      @property = property
      @property.addListener( self )
    end

    def changed( ovs , old ,newe )
      @cb.call
      @property.removeListener( self )
    end
  end

  def set_load_button_enable( enable )
    start_buttons = [ @reload_button , @split_edit_area.post_button , 
                      @clear_partial_thread_button , @sort_selector , 
                      @account_selector]
    stop_buttons  = [ @load_stop_button ]

    if enable

      start_buttons.each{|b| b.setDisable(false) }

      if stop_buttons.find{|b| b.isFocused }
        Platform.runLater{ requestFocus }
      end
      stop_buttons.each{|b| b.setDisable(true)}

    else

      if start_buttons.find{|b| b.isFocused }
        Platform.runLater{ requestFocus }
      end
      start_buttons.each{|b| b.setDisable(true) }

      stop_buttons.each{|b| b.setDisable(false )}
      
    end
  end

  # webivewとスレッド
  # http://stackoverflow.com/questions/20225264/understanding-the-javafx-webview-threading-model
  
  def start_reload( asread:false , user_present:true)
    loading( Proc.new{ reload(asread:asread, user_present:user_present) } , 
             Proc.new{ 
               set_load_button_enable( true ) 
               @shown_to_user = false
               if user_present
                 on_user_present
               end
               @last_reload = Time.now
               control_autoreload
             } ,
             Proc.new{ |e|
               # App.i.mes("#{@title} 更新失敗")
               set_status("#{App.i.now} エラー #{e}" , true) 
             }
             )
    
    
  end

  def control_autoreload
    if @autoreload_check.isSelected
      new_label = SORT_TYPES.rassoc("new")[0]
      if( @sort_selector.getSelectionModel().getSelectedItem() == new_label) or @num_comments < 200
        start_autoreload
      else
        stop_autoreload
      end
    else
      
      disable_autoreload
    end
  end

  def set_status(str , error = false)
    Platform.runLater{
      @load_status.setText( str ) 
      if error
        @load_status.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_RED};")
      else
        @load_status.setStyle("")
      end
    }
  end

  # def check_read
  #   ReadCommentDB.instance.add( @new_comments.map{|o| o[:name] } )
  #   @new_comments = []
  #   show_num_new_comments
  # end

  def check_read2
    ReadCommentDB.instance.add( @new_comments.map{|o| o[:name] } )
    ReadCommentDB.instance.set_count( @link_id , @num_comments ) 
    Platform.runLater{
      # show_num_comments
      notify_comment_fetched
    }
  end

  def on_user_present
    if not @shown_to_user
      check_read2
      Platform.runLater{
        set_tab_text( @title )
      }
      @shown_to_user = true
    end
  end

  def force_comment_clear
    begin
      Util.explicit_clear( @comments )
      Util.explicit_clear( @links )
    rescue
      $stderr.puts "コメントデータの明示的消去に失敗"
    end
  end

  def reload( asread:false , user_present:true)
    set_load_button_enable( false )
    # submission#get では、コメントが深いレベルまでオブジェクト化されない問題
    sort_type = get_current_sort
    res = if @top_comment
            App.i.client(@account_name).get( "/comments/#{@link_id}/-/#{@top_comment}.json" , limit:200 , sort:sort_type , context:@comment_context).body
          else
            App.i.client(@account_name).get( "/comments/#{@link_id}.json" , limit:200 , sort:sort_type).body
          end

    links_raw = res[0]
    comments_raw = res[1]
    
    # @links    = App.i.client.object_from_body( links_raw )
    # @comments = App.i.client.object_from_body( comments_raw )
    force_comment_clear
    @links    = object_to_deep( links_raw )
    @comments = object_to_deep( comments_raw )

    @subname  = @links[0][:subreddit]
    if @subname
      Platform.runLater{
        @subname_label.setText( @subname.to_s )
      }
    end
    
    if @subname and App.i.pref['use_sub_link_style']
      $stderr.puts "SubStyleを作成 \"#{@subname}\""
      @sub_style ||= SubStyle.from_subname( @subname )
      Thread.new{
        #puts "スタイル取得"
        st = @sub_style.get_stamp_style
        Platform.runLater{
          @comment_view.set_additional_style( st )
          @split_edit_area.set_sub_link_style( st )
          
          #puts "スタイル取得終了"
        }
      }
    end
    
    title = Html_entity.decode( @links[0].title )
    @title = title
    @num_comments = @links[0][:num_comments].to_i
   # ReadCommentDB.instance.set_count( @link_id , @num_comments ) # todo:ここでやるべきじゃない。フォーカスされた時点でやる / ユーザーが見た時点で
    Platform.runLater{
      show_num_comments
    #  notify_comment_fetched
    }

    if perm = @links[0][:permalink]
      @base_url = @url_handler.linkpath_to_url( perm )
      @comment_view.set_base_url( @base_url )
    end

    @new_comments = []
    # todo:特定のコメントだけ表示する場合に対応
    # top = @comments
    if asread
      reads = []
      comments_each(@comments){|o| reads << o[:name] }
      ReadCommentDB.instance.add( reads )
    else
      comments_each(@comments){|o|
        if not ReadCommentDB.instance.is_read( o[:name] )
          o[:reddo_new] = true
          @new_comments << o
        end
      }
    end
    Platform.runLater{
      show_num_new_comments
    }
    
    Platform.runLater{
      @comment_view.clear_comment
      # @comment_view.set_title( title ) # if @comment_view.dom_prepared
      @comment_view.set_submission( @links[0] )
      if @new_comments.length > 0 and not user_present
        set_tab_text( "(#{@new_comments.length})" + title )
        # icon color
      else
        set_tab_text( title )
      end
      @title_label.setText( title )
      @comments.each{|c| @comment_view.add_comment( c ) }
      # puts @comment_view.dump
      @comment_view.set_link_hook
      @comment_view.set_single_comment_highlight( @top_comment ) if @top_comment
      # @comment_view.set_additional_style( ".md { background: pink !important}")
      set_status(App.i.now + " 更新")
      highlight_word()
      highlight_replying(move:false)
    }
  end

  def post( obj_reply_to , md_text )
    set_load_button_enable( false )
    App.i.client( @account_name ) # refresh
    if obj_reply_to[:kind] == 't3'
      comm = obj_reply_to.add_comment(md_text)
    else
      comm , pm = obj_reply_to.reply(md_text)
    end
    if comm
      ReadCommentDB.instance.add( comm[:name] )
      Platform.runLater{
        @comment_view.add_comment( comm , recursive:false , prepend:true)
        @comment_view.set_link_hook
      }
    end
    Platform.runLater{
      @split_edit_area.set_error_message("")
      close_edit_area
    }
  end
  
  def edit( obj_edit , md_text )
    set_load_button_enable( false )
    cl = App.i.client( @account_name ) # refresh
    comm = obj_edit.edit( md_text ) # commのbody_htmlは変更されない、注意
    comm = obj_edit.client.from_fullname( obj_edit[:name] ).to_a[0]
    Platform.runLater{
      if comm[:kind] == 't3'
        @comment_view.set_submission( comm )
      else
        @comment_view.add_comment( comm , recursive:false , prepend:true)
      end
      @comment_view.set_link_hook
    }
    Platform.runLater{
      @split_edit_area.set_error_message("")
      close_edit_area
    }
  end

  DELETED_HTML_JSONSTR = "&lt;div class=\"md\"&gt;&lt;p&gt;[deleted]&lt;/p&gt;\n&lt;/div&gt;"
  def delete( obj , show_delete_element:true)
    set_load_button_enable( false )
    cl = App.i.client( @account_name )
    obj.delete!
    obj[:author] = '[deleted]'
    Platform.runLater{
      if obj[:kind] == 't3'
        if obj[:is_self]
          obj[:selftext] = '[deleted]'
          obj[:selftext_html] = DELETED_HTML_JSONSTR
        end
        @comment_view.set_submission( obj )
      else

        if show_delete_element
          obj[:body] = '[deleted]'
          obj[:body_html] = DELETED_HTML_JSONSTR
          @comment_view.add_comment( obj , recursive:false , prepend:true)
        else
          @comment_view.remove_comment( obj[:name] )
        end

      end
      
    }
  end

  def  object_to_deep( listing_ary ,depth = 0 )
    #puts "*** object_to_deep() depth:#{depth}"
    #puts "input class: #{listing_ary.class}"

    res_o = 
      if listing_ary.class == Redd::Objects::Listing
        listing_ary
      else
        App.i.client(@account_name).object_from_body( listing_ary )
      end
  
    #puts "out class: #{res_o.class}"

    if res_o
      res_o.each{|o|
        if o.class == Redd::Objects::Comment 
          # puts "child: #{o.replies.class}"

          if o.replies.kind_of?( Array ) # Listingはarray
            o[:replies] = object_to_deep( o.replies , depth + 1 )
          end
        end
      }
    
      res_o
    else
      ""
    end
  end # object_to_deep

  def comments_each(obj,&cb)
    if obj.is_a?( Redd::Objects::Comment )
      yield( obj )
      if obj.replies.kind_of?(Array)
        obj.replies.each{|o| comments_each(o,&cb) }
      end
    elsif obj.kind_of?(Array)
      obj.each{|o| comments_each(o , &cb ) }
    end
  end

  def notify_comment_fetched
    # todo 全てのsub_pageに通知する
    sub_pages = App.i.root.lookupAll(".sub-page")
    sub_pages.each{|sb|
      sb.submission_comment_fetched( @link_id , @num_comments)
    }
  end

  #####

  def key_reload
    @reload_button.fire() if not @reload_button.isDisable()
  end
  def key_top
    @comment_view.scroll_top
  end
  def key_buttom
    @comment_view.scroll_bottom
  end
  def key_up
    @comment_view.screen_up(0.6)
  end
  def key_down
    @comment_view.screen_down(0.6)
  end
  def key_previous
    @comment_view.screen_up(1.0)
  end
  def key_next
    @comment_view.screen_down(1.0)
  end
  def key_previous_paragrah
    @find_new_r_button.fire() if not @find_new_r_button.isDisable()
  end
  def key_next_paragraph
    @find_new_button.fire() if not @find_new_button.isDisable()
  end
  def key_space
    @comment_view.screen_down()
  end
  def key_find
    @find_word_box.requestFocus()
    @find_word_box.selectRange( 0 , @find_word_box.getText().length  )
  end

  def key_open_link
    if url = @links && @links[0] && @links[0][:url]
      App.i.open_external_browser(url)
    end
  end

  def key_open_link_alt
    if url = @links && @links[0] && @links[0][:url]
      App.i.open_external_browser(Util.mobile_url(url))
    end
  end

end
