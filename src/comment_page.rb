# -*- coding: utf-8 -*-

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
require 'app_color'

import 'javafx.application.Platform'

class CommentPage < Page

  SORT_TYPE = [[ "新しい" , "new"],
               [ "古い" , "old" ],
               # [ "注目" , "hot" ],
               [ "スコア" , "top" ],
               [ "ベスト","confidence"], # いわゆるbest
               [ "論争的","controversial"],
               # [ "ランダム","random"],
               [ "Q&A","qa"]
              ]

  def initialize( info , start_user_present:true)
    super()
    getStyleClass().add("comment-page")

    @new_comments = []

    @page_info = info
    @page_info[:site] ||= 'reddit'
    @page_info[:type] ||= 'comment'

    @link_id = @page_info[:name] # commentではid not fullname
    @top_comment = @page_info[:top_comment] # todo: 単独コメント機能
    @url_handler = UrlHandler.new( @page_info[:site] )
    @account_name = @page_info[:account_name] # 今のところ切り変えはない
    # @site = site
    @default_sort = @page_info[:suggested_sort] || 'new'

    @split_comment_area = VBox.new

    @shown_to_user = true

    @button_area = HBox.new()
    @button_area.setAlignment( Pos::CENTER_LEFT )
    # @button_area = ToolBar.new
    @reload_button = Button.new("リロード")
    @reload_button.setOnAction{|e|
      start_reload(asread:false)
    }
    @load_stop_button = Button.new("中断")
    @load_stop_button.setOnAction{|e|
      abort_loading
    }
    @autoreload_status = Label.new("")
    
    @sort_selector = ChoiceBox.new
    @sort_selector.getItems().setAll( SORT_TYPE.map{|ta| ta[1] } )
    @sort_selector.getSelectionModel.select( @default_sort )

    @sort_selector.valueProperty().addListener{|ov|
      start_reload( asread:false )
    }

    @title = @page_info[:title] # 暫定タイトル / これはデコードされてる
    
    name = @account_name || "なし"
    @account_label = Label.new("アカウント:" + name)

    @external_browser_button = Button.new("ブラウザで開く")
    @external_browser_button.setOnAction{|e|
      if @links and @links[0] and perm = @links[0][:permalink]
        comment_link = @url_handler.linkpath_to_url( perm )
        if @top_comment
          comment_link += @top_comment
        end
        sort = @sort_selector.getSelectionModel.getSelectedItem
        if sort != @default_sort
          comment_link += ( "?sort=" + sort )
        end
        App.i.open_external_browser( comment_link )
      end
    }

    @load_status = Label.new("")

    @button_area.getChildren().setAll( 
                                      @account_label ,
                                      Label.new(" "),
                                      @external_browser_button
                                      )

    @split_comment_area.getChildren().add( @button_area )
    self.class.setMargin( @button_area , Insets.new( 3.0 , 3.0 , 3.0 , 3.0 ))

    @button_area2 = BorderPane.new()
    # @button_area2.setAlignment( Pos::CENTER_LEFT )
    b_left = HBox.new()
    b_left.setAlignment( Pos::CENTER_LEFT )
    b_left.getChildren().setAll( @reload_button , @load_stop_button , 
                                 Label.new(" "),
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
    find1 << @find_new_r_button = Button.new("◀")
    find1 << @find_new_button = Button.new("▶")
    App.i.make_pill_buttons( find1 )
    btns3 += find1
    btns3 << Label.new(" ")
    find2 = []
    find2 << @find_word_box = TextField.new()
    @find_word_box.setPromptText("検索語")
    @find_word_box.setPrefWidth( 160 )
    find2 << @find_word_clear_button = Button.new("消")
    find2 << @find_word_r_button = Button.new("◀")
    find2 << @find_word_button = Button.new("▶")
    App.i.make_pill_buttons( find2 )
    btns3 += find2
    btns3 << Label.new(" ")
    btns3 << @find_word_count = Label.new()
    
    @find_new_button.setOnAction{|ev| scroll_to_new( true ) }
    @find_new_r_button.setOnAction{|ev| scroll_to_new( false ) }

    @find_word_box.textProperty().addListener{|ev|
      highlight_word()
    }
    @find_word_box.setOnKeyPressed{|ev|
      if ev.getCode() == KeyCode::ENTER
        @comment_view.scroll_to_highlight(true)
      end
    }
    @find_word_clear_button.setOnAction{|ev| @find_word_box.setText("") }
    @find_word_button.setOnAction{|ev| @comment_view.scroll_to_highlight( true ) }
    @find_word_r_button.setOnAction{|ev| @comment_view.scroll_to_highlight( false ) }

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

    @comment_view.set_link_cb{|link|
      page_info = @url_handler.url_to_page_info( link )
      page_info[:account_name] = @account_name
      App.i.open_by_page_info( page_info )
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

      @comment_view.set_replying( @replying[:name] , edit:false)
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

      @comment_view.set_replying( @editing[:name] , edit:true)
    }

    @split_comment_area.getChildren().add( @comment_view.webview )
    
    @split_edit_area = EditWidget.new( account_name:@account_name ,
                                       site:@site ) # リンク生成用
    @split_edit_area.set_close_cb{
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
                     close_edit_area
                     @replying = nil
                   }
                 },
                 Proc.new {
                   $stderr.puts "投稿エラー"
                 }
                 )

      elsif @editing
        loading( Proc.new{ edit( @editing , md_text ) } ,
                 Proc.new{
                   Platform.runLater{
                     set_load_button_enable( true )
                     close_edit_area
                     @editing = nil
                   }
                 },
                 Proc.new {
                   $stderr.puts "編集エラー"
                 }
                 )
      end
      
    }

    @comment_view.set_more_cb{|more , elem |

      if @links and @links[0]
        subm = @links[0]
        Thread.new{
          begin
            cl = App.i.client( @account_name )
            list = subm.expand_more_hack( more , sort:"new")
            
            list = object_to_deep( list )
            added = []
            comments_each(list){|c| 
              added << c[:name]
            }
            ReadCommentDB.instance.add( added )

            Platform.runLater{
              stop_autoreload
              @comment_view.more_result( elem , true ) # moreボタンを消す
              list.each{|c| 
                @comment_view.add_comment(c , more.parent_id ) 
                @comment_view.set_link_hook
                highlight_word()
              }
            } # runLater
            
          rescue
            $stderr.puts $!
            $stderr.puts $@
            @comment_view.more_result( elem , false )
          end
        }
      else
        @comment_view.more_result( elem , false )
      end
    }

    # @split_edit_area =  TextArea.new()
    
    @split_pane = SplitPane.new
    @split_pane.setOrientation( Orientation::VERTICAL )
    # @split_pane.getItems().setAll( @split_comment_area , @split_edit_area )
    @split_pane.getItems().setAll( @split_comment_area )
    @split_pane.setDividerPositions( 0.5 )
    
    getChildren().add( @split_pane )

    prepare_tab( @title || "取得中" , "/res/comment.png" )
    
    # Page
    @tab.setOnClosed{|ev|
      # ここはタブを明示的に閉じたときしか来ない
      $stderr.puts "comment_page onclose"
      # check_read()
      check_read2()
      finish()
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

    control_autoreload

  end # initialize
  
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
            if @editing or @replying
              interval = 60 # 編集中は延期

            elsif @last_reload and (@last_reload + target_interval ) < Time.now
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
        @autoreload_status.setStyle("-fx-background-color:#{AppColor::DARK_GREEN};-fx-text-fill:white;")
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
        @autoreload_status.setText("自動更新停止")
        @autoreload_status.setStyle("-fx-background-color:#{AppColor::DARK_RED};-fx-text-fill:white;")
    }
  end

  def set_top_comment( top_comment_id )
    @top_comment = top_comment_id
    show_single_thread_bar( true )
    start_reload( asread:false )
  end

  def show_single_thread_bar( show = true )
    if show
      # @split_comment_area.getChildren().subList(0,3).add( @button_area4 )
      @split_comment_area.getChildren().add( 3 , @button_area4 )
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
    if enable
      @reload_button.setDisable( false )
      @split_edit_area.set_post_enable
      @clear_partial_thread_button.setDisable( false )
      @sort_selector.setDisable( false )

      @load_stop_button.setDisable( true )
    else
      @reload_button.setDisable( true )
      @split_edit_area.set_post_disable
      @clear_partial_thread_button.setDisable( true )
      @sort_selector.setDisable( true )
      
      @load_stop_button.setDisable( false )
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
             } ,
             Proc.new{ |e|
               # App.i.mes("#{@title} 更新失敗")
               set_status("#{App.i.now} エラー #{e}" , true) 
             }
             )
    
    control_autoreload
  end

  def control_autoreload
    if( @sort_selector.getSelectionModel().getSelectedItem() == 'new') or @num_comments < 200
      start_autoreload
    else
      stop_autoreload
    end
  end

  def set_status(str , error = false)
    Platform.runLater{
      @load_status.setText( str ) 
      if error
        @load_status.setStyle("-fx-text-fill:red;")
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

  def reload( asread:false , user_present:true)
    set_load_button_enable( false )
    Platform.runLater{ requestFocus() }
    # submission#get では、コメントが深いレベルまでオブジェクト化されない問題
    sort_type = @sort_selector.getSelectionModel.getSelectedItem
    res = if @top_comment
            App.i.client(@account_name).get( "/comments/#{@link_id}/-/#{@top_comment}.json" , limit:200 , sort:sort_type).body
          else
            App.i.client(@account_name).get( "/comments/#{@link_id}.json" , limit:200 , sort:sort_type).body
          end

    links_raw = res[0]
    comments_raw = res[1]
    
    # @links    = App.i.client.object_from_body( links_raw )
    # @comments = App.i.client.object_from_body( comments_raw )
    @links    = object_to_deep( links_raw )
    @comments = object_to_deep( comments_raw )

    title = Html_entity.decode( @links[0].title )
    @title = title
    @num_comments = @links[0][:num_comments].to_i
   # ReadCommentDB.instance.set_count( @link_id , @num_comments ) # todo:ここでやるべきじゃない。フォーカスされた時点でやる / ユーザーが見た時点で
    Platform.runLater{
      show_num_comments
    #  notify_comment_fetched
    }

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
      
      @comments.each{|c| @comment_view.add_comment( c ) }
      # puts @comment_view.dump
      @comment_view.set_link_hook

      set_status(App.i.now + " 更新")
      highlight_word()
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
    @find_new_r_button.fire() if not @find_new_r_button.isDisable()
  end
  def key_next
    @find_new_button.fire() if not @find_new_button.isDisable()
  end
  def key_space
    @comment_view.screen_down()
  end
  def key_find
    @find_word_box.requestFocus()
    @find_word_box.selectRange( 0 , @find_word_box.getText().length  )
  end

end
