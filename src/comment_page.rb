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
require 'pref/subs'
require 'sub_pref_menu_items'

require 'user_script_base'

require 'account_selector'
require 'user_ban_state_label'

import 'javafx.application.Platform'
import 'javafx.scene.control.Alert' # jrubyfxにまだない
import 'javafx.scene.control.ButtonType'

import 'javafx.scene.control.CustomMenuItem'

class CommentPage < CommentPageBase
  include SubPrefMenuItems
  
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
    @scroll_to = @top_comment
    @comment_context = @page_info[:context]
    @url_handler = UrlHandler.new( @page_info[:site] )
    @font_zoom = @page_info[:font_zoom] || App.i.pref['comment_page_font_zoom']
    
    # すでに存在しないアカウントの棄却
    if not Account.exist?( @page_info[:account_name] )
      @page_info[:account_name] = nil
    end
    rec_account = ReadCommentDB.instance.get_subm_account(@link_id)
    if not Account.exist?( rec_account )
      ReadCommentDB.instance.get_subm_account(nil)
      rec_account = nil
    end

    sub_account = if @page_info[:subreddit] # urlからsubredditが反映できた場合など
                    Subs.new( @page_info[:subreddit] , site:@page_info[:site] )["account_name"]
                  else
                    nil
                  end

    if rec_account == false
      @account_name = false
    else
      @account_name = rec_account || sub_account || @page_info[:account_name]
      ReadCommentDB.instance.set_subm_account( @link_id , @account_name )
    end
    # @site = site
    queried_sort = if is_valid_sort_type( @page_info[:sort] )
              @page_info[:sort]
            else
              nil
            end
    
    # subredditのリスト以外から来た場合、@page_info[:suggested_sort]は機能しない。
    # 本来ならlistを１回取ってからやるべきだが…
    @default_sort = queried_sort || @page_info[:suggested_sort] || App.i.pref['default_comment_sort'] || 'new'

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
      if not @setting_default_sort
        start_reload( asread:false )
      end
      @page_info[:sort] = get_current_sort
      App.i.save_tabs
    }

    @suggested_sort_label = Label.new("")
    set_suggested_sort_label( @page_info[:suggested_sort] )

    @title = @page_info[:title] # 暫定タイトル / これはデコードされてる
    
    # name = @account_name || "なし"
    # @account_label = Label.new("アカウント:" + name)
    @account_selector = AccountSelector.new( @account_name )
    @account_selector.set_change_cb{
      if @account_name != @account_selector.get_account
        @account_name = @account_selector.get_account # 未ログイン = nil
        @comment_view.set_account_name( @account_name )
        @split_edit_area.set_account_name( @account_name )
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
    @user_ban_state_label = UserBanStateLabel.new
    ###
    @comments_menu = MenuButton.new("その他")
    create_others_menu( @comments_menu )
    @context_menu = ContextMenu.new
    create_others_menu( @context_menu )
    ####

    @load_status = Label.new("")
    
    # @subname_label = Label.new("")
    @subname_label = Hyperlink.new("...")
    # @subname_label.setStyle("-fx-text-fill:#{App.i.theme::COLOR::HTML_LINK}")
    @subname_label.setOnAction{|ev|
      open_sub
    }
    @subname_label_sep = Separator.new( Orientation::VERTICAL )

    @title_label = Label.new( @title )
    @title_label.setStyle("-fx-font-size:140%")
    button_area_left = HBox.new
    button_area_left.setAlignment( Pos::CENTER_LEFT )
    button_area_left.getChildren.setAll( @account_selector , 
                                         Label.new(" "),
                                         @user_ban_state_label,
                                         Separator.new( Orientation::VERTICAL ),
                                         @subname_label ,
                                         @subname_label_sep,
                                         )
    # 値が設定されたときに追加する
    # @subname_label.textProperty.addListener{|ov|
    #   text = ov.getValue
    #   if ((text != nil) and (text.length > 0))
    #     Platform.runLater{
    #       button_area_left.getChildren.addAll( @subname_label , @subname_label_sep )
    #     }
    #   end
    # }

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
                                 @suggested_sort_label,
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
      if @top_comment
        @comment_view.set_self_text_visible(false)
      end
      @comment_view.set_font_zoom( @font_zoom )
      start_reload( asread:check_read , user_present:start_user_present) # todo: postデータが無いときのみ trueにする
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

    @comment_view.set_reply_cb{|obj|
      open_edit_area
      
      @replying = obj
      @editing  = nil

      @split_edit_area.set_text( "" , mode:"reply" )

      highlight_replying
    }

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
        set_load_button_enable(true)
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

      if @links and @links[0]
        subm = @links[0]
        Thread.new{
          begin
            # todo: アカウントが無い場合、通常のget_commentを使って取得する
            cl = App.i.client( @account_name )
            list = subm.expand_more_hack( more , sort:"new")
            
            list = object_to_deep( list )
            
            comments_each(list){|c| 
              mark_to_ignore(c) # ignoreを先にやる: ignoreされた者はnew扱いにしないので
              mark_if_new(c)
            }

            Platform.runLater{
              
              stop_autoreload
              @comment_view.more_result( elem_id , true ) # moreボタンを消す
              list.each{|c| 
                @comment_view.add_comment(c , more.parent_id ) 
              }
              @comment_view.set_link_hook
              # @comment_view.set_spoiler_open_event
              # @comment_view.adjust_overflowing_user_flair
              highlight_word()

              show_num_new_comments
              check_read2
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

    prepare_tab( @title || "取得中" , App.i.theme::TAB_ICON_COMMENT , 
                 alt_icon_res_url:App.i.theme::TAB_ICON_COMMENT_NEW )
    
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
  
  def create_others_menu( menu )
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

    copy_url_item_short = MenuItem.new("URLをコピー(短縮)")
    copy_url_item_short.setOnAction{|e|
      App.i.copy( "https://redd.it/#{@page_info[:name]}" )
    }
    menu.getItems.add( copy_url_item_short )
    
    copy_url_md = MenuItem.new("URLをコピー(Markdown形式)")
    copy_url_md.setOnAction{|e|
      if url = make_page_url
        title_escaped = Util.escape_md( @title )
        subname = if @subname
                    " : #{@subname}"
                  else
                    ""
                  end
        App.i.copy( "[#{title_escaped}#{subname}](#{url})" )
      end
    }
    menu.getItems.add( copy_url_md )

    menu.getItems.add( SeparatorMenuItem.new )
    zoom_menu , zoom_menu_refresh_cb = make_zoom_button_menu
    menu.getItems.add( zoom_menu )
    

    sub_css_pref_menu = Menu.new("subredditのcss(旧UI系)再現")
    menu.getItems.add( SeparatorMenuItem.new )
    menu.getItems.add( sub_css_pref_menu )
    @sub_css_pref_menus ||= []
    @sub_css_pref_menus << sub_css_pref_menu # sub取得後にアイテムを追加するため

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


  def mark_if_new(o)
    if o[:name]
      if o[:reddo_ignored] != IgnoreScript::SHOW
        # ReadCommentDB.instance.add( o[:name] ) # 遅い 外でやる
      elsif o[:parent_id] and @comment_view.is_comment_hidden?( o[:parent_id] )
        # 親がすでに畳まれているものも既読にする
        # ReadCommentDB.instance.add( o[:name] ) # 遅い
      elsif (not ReadCommentDB.instance.is_read( o[:name] ))
        o[:reddo_new] = true
        @new_comments << o
      end
    end
  end

  def open_sub(focus = true)
    if @subname and not @is_multireddit
      @subname_label.setVisited(false) # visitedにしない
      url = @url_handler.subname_to_url( @subname )
      info = @url_handler.url_to_page_info( url )
      App.i.open_by_page_info(info,focus)
    end
  end

  def make_page_url
    if @base_url
      comment_link = @base_url.to_s
      if @top_comment
        comment_link += @top_comment
      end
      
      query_hash = {}

      sort = get_current_sort
      if sort != @default_sort
        # comment_link += ( "?sort=" + sort )
        query_hash[ 'sort'] = sort
      end

      if @comment_context
        query_hash[ 'context' ] = @comment_context
      end

      if query_hash.length > 0
        query = query_hash.to_a.map{|k,v| "#{k}=#{v}"}.join("&")
        comment_link += "?#{query}"
      end
      
      comment_link
    else
      nil
    end
  end

  def set_suggested_sort_label(suggested)
    if label = SORT_TYPES.rassoc(suggested)
      @suggested_sort_label.setText("(提案:#{label[0]})")
    else
      @suggested_sort_label.setText("")
    end
  end

  def focus_editarea_if_opened
    if @split_pane.getItems().length > 1
      @split_edit_area.focus_input
    end
  end

  def get_current_sort
    SORT_TYPES.assoc(@sort_selector.getSelectionModel.getSelectedItem).to_a[1]
  end

  def set_current_sort(sort)
    @sort_selector.getSelectionModel.select( SORT_TYPES.rassoc(sort).to_a[0] )
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
    @scroll_to = @top_comment
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
      @page_info[:top_comment] = @top_comment = info[:top_comment]
      @page_info[:context] = @comment_context = info[:context]
      @scroll_to = @top_comment
      if @top_comment
        show_single_thread_bar( true )
      else
        show_single_thread_bar( false )
      end
    end
    
    if info[:sort] and is_valid_sort_type( info[:sort] )
      current_sort = get_current_sort
      if current_sort != info[:sort]
        @page_info[:sort] = info[:sort]
        App.i.save_tabs
        set_current_sort( info[:sort] ) # listenerでリロードさせる
      else
        App.i.save_tabs
        start_reload( asread:false ) if changed
      end
    else
      App.i.save_tabs
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
      
      @comment_view.set_self_text_visible( false )
    else
      @split_comment_area.getChildren().remove( @button_area4 )
      @comment_view.set_self_text_visible( true )
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
    start_buttons = [ @reload_button , # @split_edit_area.post_button , 
                      @clear_partial_thread_button , @sort_selector , 
                      @account_selector]
    stop_buttons  = [ @load_stop_button ]
    
    set_load_button_enable2( enable , start_buttons , stop_buttons )
  end

  # webivewとスレッド
  # http://stackoverflow.com/questions/20225264/understanding-the-javafx-webview-threading-model
  
  def start_reload( asread:false , user_present:true)
    loading( Proc.new{ 
               reload(asread:asread, user_present:user_present)
               Platform.runLater{
                 @split_edit_area.set_comment_error(false)
               }
             },
             Proc.new{ 
               set_load_button_enable( true ) 
               Platform.runLater{
                 @split_edit_area.set_now_loading(false)
               }
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
               Platform.runLater{
                 @split_edit_area.set_comment_error(true)
               }
               $stderr.puts e.inspect
               $stderr.puts e.backtrace
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
        # set_alt_icon_status(false)
        set_tab_label_color( nil )
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
    Platform.runLater{@split_edit_area.set_now_loading(true)}
    
    set_status( "更新中…" , false , true)
    # submission#get では、コメントが深いレベルまでオブジェクト化されない問題
    ut = Thread.new{
      @user_state = UserState.from_username( @account_name )
      @user_state.refresh
    }

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
        @sub_css_pref_menus.to_a.each{|mi|
          if mi.getItems.length == 0
            create_sub_pref_menu_items( mi , 
                                        @subname )
          end
        }
      }
    end
    
    if @subname # and App.i.pref['use_sub_link_style']
      sub_pref = Subs.new( @subname , site:@site )
      @comment_view.use_link_style = (not sub_pref['dont_use_link_style'])
      @comment_view.use_user_flair_style = (not sub_pref['dont_use_user_flair_style'])
      @comment_view.enable_sjis_art( (not sub_pref['dont_use_sjis_art']) )
      
      @split_edit_area.preview.use_link_style = (not sub_pref['dont_use_link_style'])
      @split_edit_area.preview.enable_sjis_art( (not sub_pref['dont_use_sjis_art']) )

      if not (sub_pref['dont_use_link_style'] and sub_pref['dont_use_user_flair_style'] )
        $stderr.puts "SubStyleを作成 \"#{@subname}\""
        @sub_style ||= SubStyle.from_subname( @subname )
        Thread.new{
          #puts "スタイル取得"
          st = @sub_style.get_stamp_style
          Platform.runLater{
            @comment_view.set_additional_style( st )
            @split_edit_area.set_sub_link_style( st )
            # @comment_view.adjust_overflowing_user_flair
            #puts "スタイル取得終了"
          }
        }
      end
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
      if @tab.isSelected
        Platform.runLater{
          App.i.set_url_area_text( make_page_url.to_s )
        }
      end
    end

    @new_comments = []
    if asread
      reads = []
      comments_each(@comments){|o| reads << o[:name] }
      ReadCommentDB.instance.add( reads )
    else
      reads_or_folded = []
      comments_each(@comments){|o|
        mark_to_ignore(o)
        mark_if_new(o)
        reads_or_folded << o[:name] if not o[:reddo_new]
      }
      ReadCommentDB.instance.add( reads_or_folded )
    end
    Platform.runLater{show_num_new_comments}

    ut.join
    if @user_state and @user_state.user
      @comment_view.set_user_suspended( @user_state.user[:is_suspended] )
    end

    Platform.runLater{
      @user_ban_state_label.set_data( @user_state.user , @user_state.is_shadowbanned) if @user_state
      set_suggested_sort_label( @links[0][:suggested_sort] )
      @comment_view.clear_comment
      # @comment_view.set_title( title ) # if @comment_view.dom_prepared
      @comment_view.set_submission( @links[0] )
      if @new_comments.length > 0 and not user_present
        set_tab_text( "(#{@new_comments.length})" + title )
        # icon color
        # set_alt_icon_status(true)
        set_tab_label_color( App.i.theme::COLOR::STRONG_GREEN )
      else
        set_tab_text( title )
        # set_alt_icon_status(false)
        set_tab_label_color( nil )
      end
      @title_label.setText( title )
      @comments.each{|c| @comment_view.add_comment( c ) }
      @comment_view.line_image_resize( @font_zoom )
      # @comment_view.set_spoiler_open_event
      # puts @comment_view.dump
      @comment_view.set_link_hook
      @comment_view.set_single_comment_highlight( @top_comment ) if @top_comment
      # @comment_view.set_additional_style( ".md { background: pink !important}")
      set_status(App.i.now + " 更新")
      highlight_word()
      highlight_replying(move:false)
      if @scroll_to
        @comment_view.scroll_to_id_center( "t1_" + @scroll_to )
        @scroll_to = nil
      end
    }
  end

  def notify_comment_fetched
    # todo 全てのsub_pageに通知する
    sub_pages = App.i.root.lookupAll(".sub-page")
    sub_pages.each{|sb|
      sb.submission_comment_fetched( @link_id , @num_comments)
    }
  end

  def on_select
    App.i.set_url_area_text( make_page_url.to_s )
  end

  #####

  def key_previous_paragrah
    @find_new_r_button.fire() if not @find_new_r_button.isDisable()
  end
  def key_next_paragraph
    @find_new_button.fire() if not @find_new_button.isDisable()
  end

  def key_open_link
    if url = @links && @links[0] && @links[0][:url]
      App.i.open_external_browser(Html_entity.decode(url))
    end
  end

  # def key_open_link_alt
  #   if url = @links && @links[0] && @links[0][:url]
  #     App.i.open_external_browser(Util.mobile_url(Html_entity.decode(url)))
  #   end
  # end

  def key_open_sub
    open_sub
  end

  def key_open_sub_without_focus
    open_sub(false)
  end

  def key_hot
    set_current_sort( "confidence" )
  end

  def key_new
    set_current_sort( "new" )
  end

  def key_web
    if url = make_page_url
      App.i.open_external_browser( url )
    end
  end

end
