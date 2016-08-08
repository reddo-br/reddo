# -*- coding: utf-8 -*-

require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'pref/subs'
require 'pref/account'
require 'app'
require 'util'
require 'user_state'

require 'page'
require 'account_selector'
require 'user_ban_state_label'
require 'ignore_checker'

require 'url_handler'
require 'html/html_entity'

require 'glyph_awesome'

# jruby-9.0.0.0 unicode_normalizeの障害回避
require 'unicode_normalize/normalize.rb'

import 'javafx.scene.control.cell.MapValueFactory'
# import 'javafx.beans.property.SimpleStringProperty'
import 'javafx.beans.property.SimpleMapProperty'
import 'javafx.beans.property.SimpleObjectProperty'
import 'javafx.scene.control.cell.TextFieldTableCell'
import 'javafx.scene.text.TextFlow'
import 'javafx.application.Platform'
import 'javafx.util.StringConverter'
class SubPage < Page
  
  SORT_TYPES = [ # [ "注目" , "hot" , nil ],
                 # [ "新着" , "new" , nil ],
                
                [ "上昇中","rising" , nil],

                [ "トップ(時)" , "top" , :hour ],
                [ "トップ(日)" , "top" , :day  ],
                [ "トップ(月)" , "top" , :month],
                [ "トップ(年)" , "top" , :year ],
                [ "トップ(全)" , "top" , :all  ],

                [ "論争中(時)" , "controversial" , :hour ],
                [ "論争中(日)" , "controversial" , :day  ],
                [ "論争中(月)" , "controversial" , :month],
                [ "論争中(年)" , "controversial" , :year ],
                [ "論争中(全)" , "controversial" , :all  ],
                
               ]
  
  def initialize( info )
    super(3.0)
    getStyleClass().add("sub-page")
    # setStyle("-fx-border-width:1px; -fx-border-style:solid; -fx-border-color:#c8c8c8;")
    setStyle("-fx-border-width:1px; -fx-border-style:solid;-fx-border-color:#{App.i.theme::COLOR::PAGE_BORDER};")

    @page_info = info
    @page_info[:site] ||= 'reddit'
    @page_info[:type] ||= 'sub'
    
    @artificial_bold = App.i.pref["artificial_bold"]

    $stderr.puts "sub_page @page_info[:name] = #{@page_info[:name]}"
    
    @pref = Subs.new( @page_info[:name] , site:@page_info[:site] )
    setSpacing(3.0)
    @thread_pool = []
    
    # 使うアカウントの決定
    # 存在しないアカウント名なら(消された？)nilとする
    if @pref['account_name'] and not Account.exist?( @pref['account_name'] )
      @pref['account_name'] = nil
    end
    if @page_info[:account_name] and not Account.exist?( @page_info[:account_name] )
      @page_info[:account_name] = nil
    end
    # nil:未指定 false:アカウントなしを指定 (よくない
    if @pref['account_name'] == false
      @account_name = nil
    else
      @account_name = @pref['account_name'] || @page_info[:account_name] || App.i.pref['current_account'] # ページごとの記録が優先
      @pref['account_name'] = @account_name
    end
    
    @sub_info = nil
    @url_handler = UrlHandler.new( @page_info[:site] , account_name:@account_name)

    @is_multireddit = @url_handler.path_is_multireddit( @page_info[:name] )
    @is_user_submission_list = @url_handler.path_is_user_submission_list( @page_info[:name] )

    ### ボタン第一列
    # @toolbar = ToolBar.new() # ツールバーは良くない はじっこが切れるからだっけ
    @button_area = BorderPane.new
    @button_area_right = HBox.new(3.0)
    @button_area_right.setAlignment( Pos::CENTER_LEFT )
    @button_area_left = HBox.new()
    @button_area_left.setAlignment( Pos::CENTER_LEFT )

    @account_selector = AccountSelector.new( @account_name )
    # @account_selector.valueProperty().addListener{|ev|
    @account_selector.set_change_cb{ # アカウントリロード時には呼ばない
      # $stderr.puts ev.getValue()
      value = @account_selector.getValue()

      if not @account_loading
        if @account_name != @account_selector.get_account
          @account_name = @account_selector.get_account # 未ログイン = nil
          if @account_name
            @pref['account_name'] = @account_name
          else
            @pref['account_name'] = false
          end
          start_reload
        end
      end
    }
    @user_ban_state_label = UserBanStateLabel.new
    @button_area_left.getChildren.setAll( @account_selector , 
                                          Label.new(" "),
                                          @user_ban_state_label,
                                          Separator.new(Orientation::VERTICAL))

    @title_label = Label.new( make_tab_name )
    @title_label.setStyle("-fx-font-size:140%")

    @active_label = Label.new()

    # メニュー :todo 動的に
    @sub_menu_button = MenuButton.new( "その他" )
    
    external_browser_item = MenuItem.new("webで開く")
    external_browser_item.setOnAction{|e|
      url = get_sub_url
      if url.to_s.length > 0
        App.i.open_external_browser( url.to_s )
      end
    }
    @sub_menu_button.getItems.add( external_browser_item )

    if not @is_multireddit
      external_post_page_item = MenuItem.new("webで投稿ページを開く")
      external_post_page_item.setOnAction{|e|
        url = get_sub_url
        if url.to_s.length > 0
          App.i.open_external_browser( url.to_s + "/submit" )
        end
      }
      @sub_menu_button.getItems.add( external_post_page_item )
    end
    copy_url_item = MenuItem.new("urlをコピー")
    copy_url_item.setOnAction{|e|
      url = get_sub_url # addressable
      if url and url.to_s.length > 0
        App.i.copy( url.to_s )
      end
    }
    @sub_menu_button.getItems.add(copy_url_item)


    if not @is_multireddit
      copy_post_url_item = MenuItem.new("投稿ページurlをコピー")
      copy_post_url_item.setOnAction{|ev|
        url = get_sub_url
        if url and url.to_s.length > 0
          App.i.copy( url.to_s + "/submit" )
        end
      }
      @sub_menu_button.getItems.add(copy_post_url_item)
    end
    
    # サブレディットのコメント/gold一覧
    @sub_menu_button.getItems.add( SeparatorMenuItem.new)
    sub_comments_item = MenuItem.new("新着コメント")
    sub_comments_item.setOnAction{|e| App.i.open_url( get_sub_url.to_s + "/comments" ) }
    @sub_menu_button.getItems.add( sub_comments_item )
    sub_gilded_item = MenuItem.new("ゴールドを贈られたもの")
    sub_gilded_item.setOnAction{|e| App.i.open_url( get_sub_url.to_s + "/gilded") }
    @sub_menu_button.getItems.add( sub_gilded_item )

    if @is_user_submission_list
      @sub_menu_button.getItems.add( SeparatorMenuItem.new )
      @sub_menu_button.getItems.addAll( App.i.make_user_history_menuitems( @is_user_submission_list ))
    end

    if not @is_multireddit
      @subscribed_check_item = CheckMenuItem.new()
      @subscribed_check_item.setOnAction{|ev|
        sel = @subscribed_check_item.isSelected
        # $stderr.puts sel
        post_subscribed( sel )
      }
      set_subscribed_check_item_label( @account_name )
      @sub_menu_button.getItems.add( SeparatorMenuItem.new )
      @sub_menu_button.getItems.add( @subscribed_check_item )

    end
    
    @sub_menu_button.showingProperty.addListener{|ov|
      if ov.getValue
        if @subscribed_check_item
          @subscribed_check_item.setSelected( @subscribed )
        end
      end
    }

    @button_area_right.getChildren().addAll( Separator.new( Orientation::VERTICAL ),
                                             @active_label ,
                                             @sub_menu_button)

    account_area = HBox.new
    

    BorderPane.setAlignment( @button_area_left , Pos::CENTER_LEFT )
    @button_area.setLeft( @button_area_left )
    BorderPane.setAlignment( @title_label , Pos::CENTER_LEFT )
    @button_area.setCenter( @title_label )
    BorderPane.setAlignment( @button_area_right , Pos::CENTER_RIGHT )
    @button_area.setRight( @button_area_right )
    getChildren().add( @button_area )

    ### ボタン第二列
    # ソートバー
    # @sort_button_area = HBox.new()
    @sort_button_area = BorderPane.new()
    # @sort_button_area.setAlignment(Pos::CENTER_LEFT)

    @sort_button_area_left = HBox.new
    @sort_button_area_left.setAlignment(Pos::CENTER_LEFT)
    @reload_button = Button.new()
    # @reload_button.setGraphic( ImageView.new( Image.new( App.res("/res/reload.png") )))
    @reload_button.setText("リロード")
    @reload_button.setOnAction{|e|
      start_reload
    }

    @load_stop_button = Button.new()
    @load_stop_button.setText("中断")
    @load_stop_button.setOnAction{|e|
      abort_loading
    }

    # @toolbar.getItems().add( @reload_button )
    @sort_button_area_left.getChildren().addAll(@reload_button ,
                                                @load_stop_button ,
                                                Label.new(" "))
                                                
    
    # 数
    @subm_count_label = Label.new("0件")
    @subm_add_button = Button.new("追加")
    @subm_add_button.setOnAction{|ev|
      start_reload( add:true , count:100 )
    }
    @sort_button_area_left.getChildren().addAll(@subm_count_label,
                                                @subm_add_button ,
                                                Label.new(" "),
                                                Separator.new(Orientation::VERTICAL) )

    
    # @sort_button_area.setStyle("-fx-margin: 3px 3px 0px 3px")
    @sort_buttons = []

    @current_sort_other = SORT_TYPES[7]

    @sort_buttons << @sort_hot = ToggleButton.new("注目")
    @sort_buttons << @sort_new = ToggleButton.new("新着")
    @sort_buttons << @sort_others = ToggleButton.new(@current_sort_other[0])

    @sort_button_group = ToggleGroup.new()
    @sort_buttons.each{|b| b.setToggleGroup( @sort_button_group) }

    default_button = if @is_user_submission_list
                       @sort_new
                     else
                       @sort_hot
                     end
    Util.toggle_group_set_listener_force_selected( @sort_button_group ,
                                                   default_button){|btn| start_reload }
    
    @sort_selector = MenuButton.new("")
    @sort_selector.getStyleClass.add("empty-menu-button")
    SORT_TYPES.each{|name,type,span|
      item = MenuItem.new(name)
      item.setOnAction{|ev|
        @current_sort_other = [ name , type , span ]
        @sort_others.setText(name)
        if @sort_button_group.getSelectedToggle() == @sort_others
          start_reload
        else
          @sort_others.fire
        end
      }
      @sort_selector.getItems.add( item )
    }
    
    App.i.make_pill_buttons( @sort_buttons + [ @sort_selector ] )

    @sort_button_area_left.getChildren().add( Label.new("ソート:"))
    @sort_button_area_left.getChildren().addAll( @sort_buttons )
    @sort_button_area_left.getChildren().add( @sort_selector )
    @sort_button_area_left.getChildren().add( Label.new(" "))
    @sort_button_area.setLeft( @sort_button_area_left )
    
    # @load_status = Text.new()
    @load_status = Label.new()
    BorderPane.setAlignment( @load_status , Pos::CENTER_LEFT )
    @sort_button_area.setCenter( @load_status )

    getChildren.add( @sort_button_area )
    
    #### 第三列
    # filterバー
    @filter_and_search_bar = BorderPane.new()
    ###
    @filter_area = HBox.new()
    @filter_area.setAlignment( Pos::CENTER_LEFT )
    filters = []
    filters << Label.new("フィルタ:")
    f1 = []
    f1 << @filter_text = TextField.new()
    App.i.suppress_printable_key_event( @filter_text )
    @filter_text.setPromptText("単語でフィルタ")
    @filter_text.setPrefWidth( 160 )
    @filter_text.textProperty().addListener{
      display_subms
    }
    f1 << @filter_clear = Button.new("" , GlyphAwesome.make("TIMES_CIRCLE"))
    @filter_clear.setOnAction{
      @filter_text.setText("")
    }
    App.i.make_pill_buttons( f1 )
    App.i.adjust_height( f1 )
    filters += f1
    filters << Label.new(" ")

    # todo : 一度見たもの db作成後
    filters << @filter_upvoted = ToggleButton.new("UPVOTED")
    @filter_upvoted.setOnAction{
      display_subms
    }
    filters << @filter_read = ToggleButton.new("新着")
    @filter_read.setOnAction{
      display_subms
    }
    
    @filter_area.getChildren().addAll( filters )
    
    BorderPane.setAlignment( @filter_area , Pos::CENTER_LEFT )
    @filter_and_search_bar.setLeft( @filter_area )

    if not @is_multireddit
      @google_search_area = HBox.new

      parts = []

      parts << @google_search_field = TextField.new
      @google_search_field.setPromptText("Googleでsubreddit検索")
      @google_search_field.setPrefWidth( 180 )
      @google_search_field.setOnKeyPressed{|ev|
        if ev.getCode() == KeyCode::ENTER
          open_search
        elsif App.i.is_printable_key_event(ev)
          ev.consume
        end
      }

      parts << @google_search_clear_button = 
        Button.new("" , GlyphAwesome.make("TIMES_CIRCLE"))
      @google_search_clear_button.setOnAction{|ev|
        @google_search_field.setText("")
      }
      parts << @google_search_button = Button.new("", GlyphAwesome.make("SEARCH"))
      @google_search_button.setOnAction{|ev|
        open_search
      }
      
      App.i.adjust_height( parts )
      App.i.make_pill_buttons( parts )
      @google_search_area.getChildren.setAll( parts )
      
      BorderPane.setAlignment( @google_search_area , Pos::CENTER_RIGHT )
      @filter_and_search_bar.setRight( @google_search_area )
    end # is not multireddit
    
    getChildren.add( @filter_and_search_bar )
    
    #### table

    @table = TableView.new
    
    rank_column = TableColumn.new
    rank_column.setText("ﾗﾝｸ")
    rank_column.setMaxWidth(60)
    rank_column.setMinWidth(60)
    rank_column.setResizable(false)
    rank_column.setSortable(false)
    #rank_column.set_cell_value_factory{|cdf|
      #rank = @table.getItems().indexOf( cdf.getValue()) + 1
      # SimpleIntegerProperty.new( rank )
    #}
    rank_column.set_cell_value_factory( MapValueFactory.new( :reddo_rownum ))
    rank_column.set_cell_factory{|col| NumberCell.new }

    vote_column = TableColumn.new
    vote_column.set_cell_value_factory{|cdf|
      # p cdf.getValue() # Redd::Objects::Submission
      # SimpleObjectProperty.new( cdf.getValue() ) # 全データを渡す これでいいか
      SimpleObjectProperty.new( cdf.getValue() )

    }
    vote_column.set_cell_factory{|col| VoteCell.new(self) }
    vote_column.setMinWidth( 0 )
    vote_column.setPrefWidth( 40 )
    vote_column.setResizable( false)
    vote_column.setSortable(false)

    score_column = TableColumn.new
    score_column.setText("ｽｺｱ")
    score_column.setMinWidth( 60 )
    score_column.setMaxWidth( 60 )
    score_column.setPrefWidth( 60 )
    #score_column.set_cell_value_factory( MapValueFactory.new( :reddo_score ))
    #score_column.set_cell_factory{|col| NumberCell.new }
    score_column.set_cell_value_factory{ |cdf| SimpleObjectProperty.new( cdf.getValue()) }
    score_column.set_cell_factory{|col| ScoreNumberCell.new }

    thumb_column = TableColumn.new
    thumb_column.setText("画像")
    thumb_column.setMinWidth(80)
    thumb_column.setMaxWidth(80)
    thumb_column.set_cell_value_factory( MapValueFactory.new(:reddo_thumbnail_decoded))
    #thumb_column.set_cell_value_factory{ |cdf| SimpleObjectProperty.new( cdf.getValue()) }
    thumb_column.set_cell_factory{|col| ThumbCell.new }
    thumb_column.setResizable(false)
    thumb_column.setSortable(false)

    comm_column = TableColumn.new
    comm_column.setText("ｺﾒﾝﾄ数")
    comm_column.setMinWidth( 60 )
    comm_column.setMaxWidth( 60 )
    comm_column.setPrefWidth( 60 )
    comm_column.set_cell_value_factory( MapValueFactory.new( :num_comments ))
    comm_column.setSortable(false)
    comm_column.set_cell_factory{|col| NumberCell.new }

    comm_new_column = TableColumn.new
    comm_new_column.setText("新着")
    comm_new_column.setMinWidth( 60 )
    comm_new_column.setMaxWidth( 60 )
    comm_new_column.setPrefWidth( 60 )
    comm_new_column.set_cell_value_factory( MapValueFactory.new( :reddo_num_comments_new ))
    comm_new_column.setSortable(false)
    comm_new_column.set_cell_factory{|col| NumberCell.new }

    title_column = TableColumn.new
    title_column.setText("タイトル")
    title_column.set_cell_value_factory{ |cdf| SimpleObjectProperty.new( cdf.getValue()) }
    title_column.set_cell_factory{|col| 
      multi = @url_handler.path_is_multireddit( @page_info[:name])
      TitleCell.new(col, show_subreddit:multi , artificial_bold:@artificial_bold) 
    }
    title_column.prefWidthProperty().bind( @table.widthProperty.subtract(rank_column.widthProperty).subtract( vote_column.widthProperty).subtract( score_column.widthProperty ).subtract(thumb_column.widthProperty).subtract( comm_column.widthProperty ).subtract( comm_new_column.widthProperty ).subtract(20))

    title_column.setSortable(false)

    # @table.setColumnResizePolicy(TableView::CONSTRAINED_RESIZE_POLICY)
    @table.setPrefHeight( 10000 )
    @table.getColumns.setAll( rank_column , vote_column , score_column , comm_column , comm_new_column , thumb_column , title_column)

    @subs_observable = FXCollections.synchronizedObservableList(FXCollections.observableArrayList)
    @table.setItems( @subs_observable )

    @table.setContextMenu( create_context_menu )
    # @table.setFixedCellSize(javafx.scene.layout.Region::USE_COMPUTED_SIZE)
    # @table.setFixedCellSize( 100 )

    @old_selected_item = nil
    # これだとカラムとかでも反応してしまう
    #old_row_f = @table.getRowFactory() # デフォルトはnilだから
    @table.setRowFactory{|tv|
      r = javafx.scene.control.TableRow.new
      r.setOnMouseClicked{|ev|
      # if ev.getTarget().getParent().kind_of?(javafx.scene.control.TableRow)
        if not r.isEmpty()
          case ev.getButton()
          when MouseButton::PRIMARY
            item =  @table.getSelectionModel().getSelectedItem()
            if @old_selected_item == item
              open_selected_submission( (not ev.isShiftDown()) )
            else
              @old_selected_item = item
            end
          end
        end
      }
      r
    }
    
    @table.setOnKeyReleased{|ev|
      case ev.getCode()
      when KeyCode::SPACE
        # key_space
        open_selected_submission(( not ev.isShiftDown()) )
      end
    }
    
    getChildren().add( @table )

    # 本体
    self.class.setMargin( @button_area , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @sort_button_area , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @filter_and_search_bar , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @table , Insets.new(3.0, 3.0 , 0 , 3.0) )
    
    # tab
    tab_icon = if @is_user_submission_list
                 App.i.theme::TAB_ICON_USER
               else
                 App.i.theme::TAB_ICON_LIST
               end
    prepare_tab( make_tab_name , tab_icon)

    @tab.setOnClosed{
      finish()
      # タブから閉じたときしか来ないはず...
      App.i.close_history.add( @page_info , make_tab_name )
    }
    
    @permission_alert_ph = Label.new("注意：ユーザーの履歴表示には、新規の権限が必要です。旧バージョンで認可を与えたアカウントは、再度「アカウント追加」で認可を与える必要があります。")
    
    # subのデータ取得
    if @is_user_submission_list
      @active_label.setText("[history]")
    elsif @is_multireddit
      @active_label.setText("[multi]")
    else
      # start_load_sub_info
    end

    start_reload
  end # initialize
  attr_reader :is_user_submission_list

  def is_votable
    @account_name and not ( @user_state and  @user_state.user and  @user_state.user[:is_suspended] )
  end

  def post_subscribed( subscribed )
    if @sub_info and @sub_info[:name] and @account_name
      action_name = if subscribed
                      "購読しました"
                    else
                      "購読解除しました"
                    end

      App.i.background_network_job( "#{@sub_info[:display_name]}を#{action_name}" ,
                                    "購読処理失敗" ){
        cl = App.i.client( @account_name )
        act = if subscribed
                'sub'
              else
                'unsub'
              end
        ret = cl.post( '/api/subscribe.json' , 
                       sr:@sub_info[:name] , # not display name
                       action:act ).body
        @subscribed = subscribed
        # $stderr.puts ret
      }
    end
  end

  def open_search
    word = @google_search_field.getText().strip
    if word.length > 0 
      page_info = { 
        :type => "google_search",
        :subname => @page_info[:name] ,
        :word => word,
        :account_name => @account_name
      }
      App.i.open_by_page_info( page_info )
    end
  end

  def make_tab_name
    if @is_multireddit or @is_user_submission_list # url_handler内で決めたタイトルを使う
      if @page_info[:title]
        @page_info[:title]
      else
        if @page_info[:name] = "../"
          "フロントページ"
        else
          "no title"
        end
      end
    else
      if @sub_info
        @sub_info[:display_name]
      else
        subpath_to_name(@page_info[:name])
      end
    end
  end

  def load_sub_info
    begin
      @sub_info = App.i.client(@account_name).subreddit_from_name( @page_info[:name] )
      if @sub_info
        title = @sub_info[:title] || make_tab_name
        @subscribed = @sub_info[:user_is_subscriber]
        Platform.runLater{
          @title_label.setText( Html_entity.decode(title) )
          set_tab_text( make_tab_name )
          set_subscribed_check_item_label( @account_name )
          # @subscribed_check_item.setSelected( @subscribed ) # メニュー表示時にやる
          active = Util.comma_separated_int( @sub_info[:accounts_active].to_i )
          subscribers = Util.comma_separated_int(@sub_info[:subscribers].to_i )
          @active_label.setText("ユーザー数: #{active} / #{subscribers}")
        }
      end
    rescue
      $stderr.puts "sub情報取得失敗"
    end
  end

  def set_subscribed_check_item_label( account_name )
    if @account_name
      @subscribed_check_item.setText("購読@" + @account_name.to_s)
    else
      @subscribed_check_item.setText("購読")
    end
    
    if account_name
      @subscribed_check_item.setDisable(false)
    else
      @subscribed_check_item.setDisable(true)
    end
  end

  def finish
    # if @load_sub_info_thread
    #   begin
    #     @load_sub_info_thread.kill
    #   rescue
        
    #   end
    #   @load_sub_info_thread = nil
    # end
  end
  
  def subname_to_pathname(name)
    @url_handler.subname_to_url(name).path
  end

  def subpath_to_name(path)
    if path == "../"
      "フロントページ"
    else
      File.basename(path)
    end
  end

  def start_reload(add:false , count:100)
    loading( Proc.new{ reload(add:add , count:count) } , 
             Proc.new{ 
               set_load_button_enable( true ) 
               if not add
                 Platform.runLater{ 
                   @table.scrollTo(0) 
                   select_row( 0 )
                 }
               end
             } , 
             Proc.new{ |e| 
               set_status("#{App.i.now} エラー #{e}" , true) 
               
             }
             )
  end

  def set_status(str , error = false , loading = false)
    Platform.runLater{
      @load_status.setText( str ) 
      if error
        @load_status.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_RED};")
      elsif loading
        @load_status.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};")
      else
        @load_status.setStyle("")
      end
    }
  end

  def set_placeholder
    if @is_user_submission_list and @account_name
      if Account.byname( @account_name ).scopes.index("history")
        Platform.runLater{
          @table.setPlaceholder(nil)
        }
      else
        Platform.runLater{
          @table.setPlaceholder(@permission_alert_ph)
        }
      end
    end
  end
  
  def reload( add:false , count:100)
    $stderr.puts "reload"
    set_placeholder

    set_load_button_enable( false )
    set_status( "更新中…" , false , true)
    Thread.new{ load_sub_info } if not @is_multireddit
    ut = Thread.new{
      @user_state = UserState.from_username( @account_name )
      @user_state.refresh
    }

    cl = App.i.client(@account_name)
    $stderr.puts cl.access.to_json ########
    
    after = if add and @subms.to_a.length > 0
              @subms.last[:name]
            else
              @subms = []
              nil
            end
    
    begin
=begin
      subms = case @sort_button_group.getSelectedToggle()
               when @sort_hot
                 cl.get_hot( @page_info[:name] , limit:count , after:after)
               when @sort_new
                 cl.get_new( @page_info[:name] , limit:count , after:after)
               when @sort_contr_day
                 cl.get_controversial( @page_info[:name] , 
                                       {:limit => count , :t => :day , after:after})
               when @sort_contr_week
                 cl.get_controversial( @page_info[:name] , 
                                       {:limit => count , :t => :week ,after:after})
               end
=end
      
      sort_type , timespan = 
        case @sort_button_group.getSelectedToggle()
        when @sort_hot
          [ 'hot' , nil ]
        when @sort_new
          ['new' , nil ]
        when @sort_others
          sa = @current_sort_other
          [ sa[1] , sa[2] ]
        end

      subms = 
        if @is_user_submission_list and @account_name # アカウントが無いとデータの形式が違う？ので通常のサブレディットとして取る
          path = Pathname.new("/r/") / @page_info[:name]
          $stderr.puts "ユーザーリストの取得 #{path}"
          resp = cl.get( path.to_s , limit:count, sort:sort_type , 
                         after:after , t:timespan ).body
          cl.object_from_body(resp)
        else
          case sort_type
          when 'hot'
            cl.get_hot( @page_info[:name] , limit:count , after:after)
          when 'new'
            cl.get_new( @page_info[:name] , limit:count , after:after)
          when 'rising'
            path = @url_handler.subname_to_url( @page_info[:name]).path.to_s
            rpath = path + "/rising.json"
            $stderr.puts "rising用パス #{rpath}"
            raw = cl.get( rpath , limit:count , after:after).body
            cl.object_from_body( raw )
          when 'controversial'
            cl.get_controversial( @page_info[:name] , 
                                  {:limit => count , :t => timespan , after:after})
          when 'top'
            cl.get_top( @page_info[:name] , 
                            {:limit => count , :t => timespan , after:after})
          when 'gilded'
            path = @url_handler.subname_to_url( @page_info[:name]).path.to_s
            rpath = path + "/gilded.json"
            raw = cl.get( rpath , limit:count , after:after).body
            cl.object_from_body( raw )
          end
        end
      
      ut.join
      Platform.runLater{
        if @user_state
          @user_ban_state_label.set_data( @user_state.user , @user_state.is_shadowbanned)
        end
      }

      # todo:存在しないsubの対応
      # todo:randomの対応

      if subms
        subms.each_with_index{|obj,i|
          obj[:reddo_rownum] = i + 1 + @subms.length
          # score hack
          obj[:reddo_orig_vote_score] = if obj[:likes] == true
                                          1
                                        elsif obj[:likes] == false
                                          -1
                                        else
                                          0
                                        end
          obj[:reddo_vote_score] = obj[:reddo_orig_vote_score]
          obj[:reddo_score] = obj[:score]
          obj[:title_decoded] = Html_entity.decode( obj[:title] )
          obj[:title_for_match] = obj[:title_decoded].to_s.unicode_normalize(:nfkc).downcase
          
          obj[:reddo_thumbnail_decoded] = Util.decoded_thumbnail_url( obj )
          
          set_num_comments_new( obj )
          
        }

        @subms += subms

        set_status( App.i.now + " 更新")
        if add
          display_subms(addition:subms)
        else
          display_subms
        end
      else
        # 存在しないsubか
        set_status( App.i.now + " サブレディットが見つかりません" , true)
      end
    rescue Redd::Error::PermissionDenied
      set_status( App.i.now + " アクセスできません" , true)
      @subms = []
      display_subms
    end

  end # subs

  def set_num_comments_new( obj )
    fetched = ReadCommentDB.instance.get_count( obj[:id] )
    if fetched
      obj[:reddo_num_comments_new] = [obj[:num_comments] - fetched , 0].max
    end
  end

  def get_sub_url
    if @sub_info
      # "/r/newsokur/" など 最後に/がある
      sub_url = @sub_info[:url].sub(/\/$/,'')
      @url_handler.linkpath_to_url( sub_url ) 
    else
      au = @url_handler.subname_to_url( @page_info[:name] )
      if au.path == '/'
        au.path = ""
      end
      $stderr.puts "■get_sub_url: #{au.to_s}"
      au
    end
  end

  def display_subms(addition:nil)
    old_top = get_scroll_top.to_i # nilなら0
    if addition
      @subs_observable.addAll( filter(addition) )
    else
      @subs_observable.setAll( filter(@subms) ) # eventを発行しない
    end
    Platform.runLater{
      @subm_count_label.setText("#{@subms.length}件")
      @table.scrollTo(old_top)

      if @table.getSelectionModel().getSelectedIndex == -1
        @table.getSelectionModel().select( old_top )
      end
      am = App.i.pref['sub_scroll_amount']
      set_scroll_amount( am )
    }
  end

  def get_virtual_flow
    @virtual_flow ||= if ch = @table.getChildren() and ch.size() > 1
                        ch.get(1)
                      else
                        nil
                      end
    @virtual_flow
  end

  def get_scroll_top( within_view_port = true )
    if vf = get_virtual_flow
      cell = if within_view_port 
               vf.getFirstVisibleCellWithinViewPort() || vf.getFirstVisibleCell()
             else
               vf.getFirstVisibleCell()
             end
      if cell
        cell.getIndex()
      else
        nil
      end
    else
      nil
    end
  end

  def selection_is_in_view( within_view_port = true )
    sel = @table.getSelectionModel.getSelectedIndex()
    (st = get_scroll_top(within_view_port) ) and (st <= sel ) and 
      (ed = get_scroll_bottom(within_view_port) ) and (sel <= ed)
  end

  def get_scroll_bottom( within_view_port = true )
    if vf = get_virtual_flow
      cell = if within_view_port 
               vf.getLastVisibleCellWithinViewPort() || vf.getLastVisibleCell()
             else
               vf.getLastVisibleCell()
             end
      if cell
        cell.getIndex()
      else
        nil
      end
    else
      nil
    end
  end

  def screen_scroll( forward , ratio = 1.0 )
    first = get_scroll_top
    last  = get_scroll_bottom
    if first and last
      amount = ((last - first + 1) * ratio).to_i
      amount = 1 if amount < 1

      amount = if forward
                 amount
               else
                 amount * -1
               end

      # $stderr.puts "screen_scroll #{first} + #{amount}"

      target = first + amount

      @table.scrollTo( target )
      target
    end
  end

  def set_scroll_amount( amount = 0.6 )
    if vf = get_virtual_flow
      if amount
        vf.setOnScroll{|ev|
          screen_scroll( ev.getDeltaY() < 0 , amount) # -1なら↓
          ev.consume
        }
      #else
      #  vf.setOnScroll(nil)
      end
    end
  end

  def filter(subms_in)
    word = @filter_text.getText().to_s.unicode_normalize(:nfkc).downcase
    filter_upvoted = @filter_upvoted.isSelected()

    subms = subms_in

    subms = subms.find_all{|subm| 
      IgnoreChecker.instance.check(subm) == IgnoreScript::SHOW or subm[:author] == @account_name
    }

    if( word.length > 0 )
      subms = subms.find_all{|subm|
        subm[:title_for_match].to_s.index( word ) or
        subm[:author].to_s.downcase.index( word ) or
        subm[:link_flair_text].to_s.downcase.index(word)
      }
    end

    if filter_upvoted
      subms = subms.find_all{|subm| subm[:reddo_vote_score] == 1 }
    end
    if @filter_read.isSelected()
      subms = subms.find_all{|subm| subm[:reddo_num_comments_new].to_i > 0 }
    end

    subms
  end

  def set_load_button_enable( enable )
    start_buttons = [ @reload_button , @account_selector , @subm_add_button , @sort_selector] + @sort_buttons
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

  def open_selected_submission( set_focus = true )
    # url = item_to_comment_link( @table.getSelectionModel().getSelectedItem() )
    item =  @table.getSelectionModel().getSelectedItem()
    subm_id = item[:id]
    title   = item[:title_decoded]
    # App.i.open_comment( link_id:subm_id , title:title , account_name:@account_name )
    comm_account = @account_name || false # falseではcomment側で自動でアカウントを設定しない
    App.i.open_by_page_info( { :site  => @page_info[:site] ,
                               :type  => 'comment',
                               :name  => subm_id , 
                               :title => title , # 暫定表示用
                               :suggested_sort => item[:suggested_sort],
                               :account_name => comm_account } ,
                             set_focus)
    
  end

  class VoteCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl
    STYLE_BASE = "-fx-font-size:100%;"
    def initialize(page)
      super()
      @page = page
      @upvote_button = ToggleButton.new("▲")
      @upvote_button.setStyle(STYLE_BASE)
      @upvote_button.getStyleClass().add("upvote-button")
      @downvote_button = ToggleButton.new("▼")
      @downvote_button.setStyle(STYLE_BASE)
      @downvote_button.getStyleClass().add("downvote-button")

      App.i.make_pill_buttons( [ @upvote_button , @downvote_button ] , true )

      tg = ToggleGroup.new()
      @upvote_button.setToggleGroup(tg)
      @downvote_button.setToggleGroup(tg)

      tg.selectedToggleProperty().addListener{|ov , old_tb , new_tb|
        # $stderr.puts "セレクション変更"
        vote_score = 0
        if @upvote_button.isSelected
          vote_score = 1
          @upvote_button.setStyle("#{STYLE_BASE} -fx-text-fill:#{App.i.theme::COLOR::UPVOTED}")
        else
          @upvote_button.setStyle(STYLE_BASE)
        end
        if @downvote_button.isSelected
          vote_score = -1
          @downvote_button.setStyle("#{STYLE_BASE} -fx-text-fill:#{App.i.theme::COLOR::DOWNVOTED}")
        else
          @downvote_button.setStyle(STYLE_BASE)
        end
        
        it = getTableRow().getItem
        if it and it[:reddo_vote_score] != vote_score
          getTableView().getItems().subList( index , index + 1).replaceAll{|item| 
            page.set_vote_score_and_vote( item , vote_score )
            item
          }
        end
      }

      box = VBox.new()
      box.getChildren().add( @upvote_button )
      box.getChildren().add( @downvote_button )

      box.setAlignment( Pos::CENTER_LEFT )

      setGraphic( box )

    end
    
    def updateItem( data , is_empty_col )
      sub_page = @page
      if is_empty_col
        @upvote_button.setVisible( false )
        @downvote_button.setVisible( false )
        
        @upvote_button.setUserData( nil )
        @downvote_button.setUserData( nil )

      else
        @upvote_button.setVisible( true )
        @downvote_button.setVisible( true )

        @upvote_button.setUserData( data[:name] )
        @downvote_button.setUserData( data[:name] )

        if sub_page.is_votable and not data[:archived]
          @upvote_button.setDisable( false )
          @downvote_button.setDisable( false )
        else
          @upvote_button.setDisable( true )
          @downvote_button.setDisable( true)
        end

        if data[:reddo_vote_score] == 1
          @upvote_button.setSelected( true )
          @downvote_button.setSelected( false )
        elsif data[:reddo_vote_score] == -1
          @upvote_button.setSelected( false )
          @downvote_button.setSelected( true )
        else
          @upvote_button.setSelected( false )
          @downvote_button.setSelected( false )
        end

      end

    end # updateItem
  end

  # score cell

  class ThumbCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl
    IMAGE_WIDTH = 74
    IMAGE_HEIGHT = 54
    # IMAGE_SIZE = 50
    def initialize
      super()
      setPadding( Insets.new( 2, 2, 2, 2 ))
      @image_view = ImageView.new
      @image_view.setSmooth(true)
      # @image_view.setCache(true)
      @image_view.setPreserveRatio(true)
      @image_view.setFitWidth( IMAGE_WIDTH )
      @image_view.setFitHeight( IMAGE_HEIGHT )
      setAlignment( Pos::CENTER )
      setMinHeight(IMAGE_HEIGHT + 6)
      setMinWidth(IMAGE_WIDTH + 6)
      setGraphic( @image_view)
    end

    @@cache = {}

    def updateItem( data , is_empty_col )

      if data and not is_empty_col
        url = data
        # p url
        # i = @@cache[ url ] || Image.new( url, IMAGE_SIZE, IMAGE_SIZE, true,true,true) # ratio,smooth,background
        i = @@cache[ url ] || Image.new( url ,true) # background
        @@cache[ url ] = i
        @image_view.setImage( i )
      else
        @image_view.setImage(nil)
      end
      
    end
    
    def resize_keep_ratio( target_width , target_height , width , height )

    end

  end

  class NumberCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl

    def initialize
      super()
      @number = Label.new
      @number.setStyle( "-fx-font-size:150%")
      setAlignment( Pos::CENTER_RIGHT )
      setGraphic(@number)
    end

    def updateItem( data , is_empty_col )
      if data and not is_empty_col
        @number.setText(data.to_s)
      else
        @number.setText("")
      end
    end
  end

  class ScoreNumberCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl

    def initialize
      super()
      @number = Label.new
      @number.setStyle( "-fx-font-size:150%")
      setAlignment( Pos::CENTER_RIGHT )
      setGraphic(@number)
    end

    def updateItem( data , is_empty_col )
      if data and not is_empty_col
        case data[:reddo_vote_score]
        when 1
          @number.setStyle( "-fx-font-size:150%;-fx-text-fill:#{App.i.theme::COLOR::UPVOTED}")
        when -1
          @number.setStyle( "-fx-font-size:150%;-fx-text-fill:#{App.i.theme::COLOR::DOWNVOTED}")
        else
          @number.setStyle( "-fx-font-size:150%;")
        end
        
        @number.setText(data[:reddo_score].to_s )
      else
        @number.setText("")
      end
    end
  end

  class TitleCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl

    @@dummy_label = nil
    @@dummy_scene = nil

    def initialize(col = nil , artificial_bold:false, show_subreddit:false)
      super()
      @show_subreddit = show_subreddit

      # @subm_title = Label.new
      @subm_title = Text.new
      color = if App.i.pref['use_dark_theme']
                'white'
              else
                'black'
              end
      
      if artificial_bold
        # drowshadow ( blur-type , color , radius , spread, offset_x , offset_y )
        # @subm_title.setStyle( "-fx-font-size:14px; -fx-word-wrap:break-word; -fx-effect: dropshadow( one-pass-box , black , 0,0,1,0 );")
        @subm_title.setStyle( "-fx-fill:#{color}; -fx-font-size:115%; -fx-word-wrap:break-word; -fx-effect: dropshadow( one-pass-box , #{color} , 0,0,1,0 );")
      else
        @subm_title.setStyle( "-fx-fill:#{color}; -fx-font-size:115%; -fx-font-weight: bold; -fx-word-wrap:break-word")
      end

      if @show_subreddit
        @subreddit = Label.new
        @subreddit.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};-fx-padding:0 6px 0 0;")
        @subreddit.setWrapText(false)
      end

      @nsfw = Label.new("NSFW")
      @nsfw.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::STRONG_RED}")
      @nsfw.setWrapText(false)

      @link_flair = Label.new
      @link_flair.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::HTML_TEXT_THIN};")
      @link_flair.setWrapText(false)

      @datetime = Label.new
      @datetime.setStyle( "-fx-padding:0 6px 0 0;")
      @datetime.setWrapText(false)

      @sticky = Label.new("Sticky")
      @sticky.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::STRONG_GREEN}")
      @sticky.setWrapText(false)

      @locked = Label.new("Locked")
      @locked.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::STRONG_YELLOW}")
      @locked.setWrapText(false)

      @author = Label.new
      @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_BLUE};")
      @author.setWrapText(false)
      
      @user_flair = Label.new
      @user_flair.setStyle( "-fx-border-color:#{App.i.theme::COLOR::BASE}; -fx-border-width: 1 1 1 1" )
      @user_flair.setMaxWidth( 200 )
      @user_flair.setWrapText(false)

      @gilded = Label.new
      @gilded.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_YELLOW};")
      @gilded.setWrapText(false)

      @domain = Label.new
      @domain.setWrapText(false)
      @domain.setStyle("-fx-padding:0 6px 0 6px;")
      #####

      # setPrefHeight( 1 ) # これをやるとwrapできなくなる

      @hbox = HBox.new()
      # @hbox = FlowPane.new(Orientation::HORIZONTAL)
      @hbox.setAlignment( Pos::CENTER_LEFT )
      
      @hbox.getChildren().add( @datetime )
      @hbox.getChildren().add( @author )
      @hbox.getChildren().add( @user_flair )
      @hbox.getChildren().add( @gilded )

      @hbox2 = HBox.new()
      @hbox2.setAlignment( Pos::CENTER_LEFT )
      @hbox2.getChildren().add( @subreddit ) if @show_subreddit
      @hbox2.getChildren().add( @nsfw )
      @hbox2.getChildren().add( @locked )
      @hbox2.getChildren().add( @sticky )
      @hbox2.getChildren().add( @link_flair )
      @hbox2.getChildren().add( @domain )

      @box = VBox.new
      @box.setAlignment( Pos::TOP_LEFT )
      @box.getChildren().add( @subm_title )
      @box.getChildren().add( @hbox2 )
      @box.getChildren().add( @hbox )

      # box.prefHeightProperty().bind( self.heightProperty()) # wrapしなくなる
      # self.heightProperty().bind( box.heightProperty())
      # self.heightProperty().bind( box.heightProperty())
      # @box.setPrefHeight(70) # 固定されてしまう -> あとでまた変える
      # @subm_title.heightProperty().addListener{

      widthProperty().addListener{|ev|
        @subm_title.setWrappingWidth( getWidth() - 4)
      }

      setGraphic( @box )
    end

    def updateItem( data , is_empty_col )

      if( data and not is_empty_col )


        time = Time.at( data[:created_utc] )
        @datetime.setText( time.strftime("%Y-%m-%d %H:%M:%S") )

        if @show_subreddit
          @subreddit.setText( data[:subreddit] )
        end

        fl = data[:link_flair_text].to_s.strip
        if fl.length > 0
          @link_flair.setVisible(true)
          @link_flair.setText( fl )
        else
          @link_flair.setVisible(false)
          @link_flair.setText("")
        end

        if data[:over_18]
          @nsfw.setText("NSFW")
          @nsfw.setVisible(true)
        else
          @nsfw.setText("")
          @nsfw.setVisible(false)
        end

        if data[:stickied]
          @sticky.setText(" Sticky ")
          @sticky.setVisible(true)
        else
          @sticky.setText("")
          @sticky.setVisible(false)
        end

        if data[:locked]
          @locked.setText(" Locked ")
          @locked.setVisible(true)
        else
          @locked.setText("")
          @locked.setVisible(false)
        end

        author = data[:author].to_s
        if d = data[:distinguished]
          author += "[" + d[0].to_s + "]"
          if d == 'moderator'
            @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};")
          elsif d == 'admin'
            @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_RED};")
          else
            @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_BLUE};")
          end
        else
          @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_BLUE};")
        end
        @author.setText( author )

        if afl = data[:author_flair_text] and afl.to_s.length > 0
          @user_flair.setText( afl )
          @user_flair.setVisible(true)
        else
          @user_flair.setText( "" )
          @user_flair.setVisible(false)
        end
        
        if data[:gilded] == 1
          @gilded.setText("★")
        elsif data[:gilded] > 1
          @gilded.setText("★" + data[:gilded].to_s )
        else
          @gilded.setText("")
        end

        @domain.setText( "(" + data[:domain].to_s + ")" )

        # @subm_title.setText( data[:title_decoded].to_s.strip  )
        @subm_title.setText( Util.cjk_nobreak(data[:title_decoded].to_s.strip) )
        # height = calc_title_height( @subm_title.getWidth(),
        #                             data[:title_decoded].to_s.strip,
        #                             @subm_title.getStyle() )
        # p height

        @box.setVisible(true)
      else
        @box.setVisible(false)
      end
    end

  end
  
  # commcount
  # new
  
  # TextFlowでTextを流し込めるもよう
  # [タイトル]
  # 時間 投稿者 ソースドメイン

  # hide , browser などのコマンドはコンテクストで

  def create_context_menu
    # cancel_menu = MenuItem.new("キャンセル")
    # cancel_menu.setOnAction{|e|
    #  //
    # }

    open_external = MenuItem.new("リンクを開く")
    open_external.setOnAction{|e|
      if item = @table.getSelectionModel().getSelectedItem()
        url = item[:url]
        
        page_info = @url_handler.url_to_page_info( url )
        if page_info[:type] == 'other'
          App.i.open_external_browser(url)
        else
          App.i.open_by_page_info( page_info )
        end
        
      end
    }
    open_external_r = MenuItem.new("リンクを開く(readability)")
    open_external_r.setOnAction{|e|
      if item = @table.getSelectionModel().getSelectedItem()
        url = item[:url]
        
        page_info = @url_handler.url_to_page_info( url )
        if page_info[:type] == 'other'
          url_r = Util.mobile_url( url )
          App.i.open_external_browser(url_r)
        else
          App.i.open_by_page_info( page_info )
        end

      end
    }
    open_comment_external = MenuItem.new("コメントを外部ブラウザで開く")
    open_comment_external.setOnAction{|e|
      if item = @table.getSelectionModel().getSelectedItem()
        url = item_to_comment_link( item )
        App.i.open_external_browser( url )
      end
    }

    menu = ContextMenu.new
    menu.getItems().addAll( open_external , open_external_r , open_comment_external )

    if @url_handler.path_is_multireddit( @page_info[:name] )
      
      open_sub = MenuItem.new( "Subredditを開く")
      open_sub.setOnAction{|e|
        open_selected_item_subreddit
      }
      
      menu.getItems().add( open_sub )
    end

    ### toggleメニュー
    menu.getItems().add( SeparatorMenuItem.new )
    hide_item = CheckMenuItem.new("hide")
    hide_item.setOnAction{|ev| # onShowingで呼ばれないようにactionで
      if obj = @table.getSelectionModel().getSelectedItem()
        set_object_hidden( obj , hide_item.isSelected)
      end
    }
    menu.getItems().add( hide_item )
    save_item = CheckMenuItem.new("save")
    save_item.setOnAction{|ev| # onShowingで呼ばれないようにactionで
      if obj = @table.getSelectionModel().getSelectedItem()
        set_object_saved( obj , save_item.isSelected)
      end
    }
    menu.getItems().add( save_item )

    # 対象によるメニュー内容の切り変え
    menu.setOnShowing{|e|
      item = @table.getSelectionModel().getSelectedItem()
      url = item[:url]
      comm_url = item_to_comment_link( item )

      if url =~ /^http/ and not url == comm_url
        open_external.setVisible( true )
      else
        open_external.setVisible( false)
      end

      # toggle系
      hide_item.setSelected( item[:hidden] )
      save_item.setSelected( item[:saved] )
    }

    menu
  end

  def open_selected_item_subreddit(focus = true)
    if item = @table.getSelectionModel().getSelectedItem()
      subname = item[:subreddit]
      page_info = { 
        type:"sub" , 
        site:@page_info[:site] , 
        name:subname ,
        account_name: @account_name
      }
      App.i.open_by_page_info( page_info , focus)
    end
  end

  def item_to_comment_link( item )
    path = item[:permalink] # pass
    @url_handler.linkpath_to_url(path)
  end

  # commentページ上での変更を反映させる
  def submission_voted( subm_id )
    # not implemented
  end

  def submission_comment_fetched( subm_id , count )
    target = nil
    @subms.to_a.each{|obj|
      if obj[:id] == subm_id
        obj[:num_comments] = count
        set_num_comments_new( obj )
        target = obj
      end
    }
    if target
      replace_item( target )
    end
  end

  def replace_item( obj )
    index = @table.getItems().find_index{|o| o[:id] == obj[:id] }
    if index
      @table.getItems().subList( index , index + 1 ).replaceAll{|old|
        obj
      }
    end
  end

  def calc_new_vote_score( obj , upvote_key )
    if obj[:reddo_vote_score].to_i == 0
      if upvote_key
        1
      else
        -1
      end
    elsif obj[:reddo_vote_score].to_i == 1
      if upvote_key
        0
      else
        -1
      end
    elsif obj[:reddo_vote_score].to_i == -1
      if upvote_key
        1
      else
        0
      end
    else
      0
    end
  end

  def set_vote_score_and_vote( obj , vote_score )
    obj[:reddo_score] = obj[:score] - obj[:reddo_orig_vote_score] + vote_score
    obj[:reddo_vote_score] = vote_score

    vote_val = case vote_score
               when 1
                 true
               when -1
                 false
               when 0
                 nil
               end
    vote( obj , vote_val ) # Page
  end

  def on_select
    App.i.set_url_area_text( get_sub_url.to_s )
  end

  #####
  #
  # key
  #
  #####
  
  def key_reload
    @reload_button.fire() if not @reload_button.isDisable()
  end
  def key_top
    @table.scrollTo( 0 )
    select_row( 0 )
  end
  def key_buttom
    @table.scrollTo( @table.getItems().size - 1 )
    select_row( @table.getItems().size - 1 )
  end
  
  def key_up
    # 選択の移動
    index = @table.getSelectionModel().getSelectedIndex()
    if index >= 0 # どこかが選択されていれば
      if selection_is_in_view(false)
        if index > 0
          $stderr.puts "set selection"
          select_row( index - 1 )
          if not selection_is_in_view
            @table.scrollTo( index - 1)
          end
        end
      else
        select_row( get_scroll_bottom ) # 下から出てくる
      end
    else
      select_row( get_scroll_top ) # 最初はトップ
    end
  end
  
  def key_down
    index = @table.getSelectionModel().getSelectedIndex()
    if index >= 0
      if selection_is_in_view(false) 
        
        if index < @table.getItems().size - 1
          select_row( index + 1 )
          if not selection_is_in_view
            @table.scrollTo( index + 1 - (get_scroll_bottom - get_scroll_top) )
          end
        end
        
      else
        select_row( get_scroll_top ) # 上から出てくる
      end
    else
      select_row( get_scroll_top ) # 最初はトップ
    end
  end

  #def key_space
  #  key_next
  #end

  def key_previous
    new_top = screen_scroll( false )
    # ついてこれない
    select_row( new_top )
  end
  def key_next
    new_top = screen_scroll( true )
    select_row( new_top )
  end
  
  def select_row( index )
    # @table.getSelectionModel().setSelectedIndex( index )
    @table.requestFocus()
    @table.getFocusModel().focus( index )
    @table.getSelectionModel().select( index ) # TableView.TableViewSelectionModel#
  end

  def set_focus_on_selection()
    si = @table.getSelectionModel.getSelectedIndex
    fi = @table.getFocusModel.getFocusedIndex
    if si >= 0 and fi != si
      @table.getFocusModel.focus(si)
    end
  end

  #
  #
  #

  def key_open_link
    if item = @table.getSelectionModel().getSelectedItem()
      url = item[:url]
      App.i.open_external_browser(url)
    end
  end
  
  def key_open_link_alt
    if item = @table.getSelectionModel().getSelectedItem()
      url = item[:url]
      App.i.open_external_browser(Util.mobile_url(url))
    end
  end
  
  def key_open_comment
    $stderr.puts "sub_page.rb:key_o()"
    open_selected_submission()
  end
  
  def key_open_comment_without_focus
    $stderr.puts "sub_page.rb:key_o()"
    open_selected_submission(false)
  end
  
  def key_open_sub
    open_selected_item_subreddit()
  end
  
  def key_open_sub_without_focus
    open_selected_item_subreddit(false)
  end
  
  def key_add
    @subm_add_button.fire() if not @subm_add_button.isDisable()
  end

  def key_hot
    @sort_hot.fire() if not @sort_hot.isDisable()
    #if not @sort_selector.isDisable()
    #  @sort_selector.getSelectionModel.select( SORT_TYPES.rassoc('hot')[0])
    #end
  end

  def key_new
    @sort_new.fire() if not @sort_new.isDisable()
    #if not @sort_selector.isDisable()
    #  @sort_selector.getSelectionModel.select( SORT_TYPES.rassoc('new')[0] )
    #end
  end

  def key_upvote()
    if is_votable
      item = @table.getSelectionModel().getSelectedItem()
      new_score = calc_new_vote_score( item , true )
      replace_item( item )
      set_vote_score_and_vote( item , new_score )
      Platform.runLater{ set_focus_on_selection }
    end
  end

  def key_downvote
    if is_votable
      item = @table.getSelectionModel().getSelectedItem()
      new_score = calc_new_vote_score( item , false )
      replace_item( item )
      set_vote_score_and_vote( item , new_score )
      Platform.runLater{ set_focus_on_selection }
    end
  end

  def key_find
    @filter_text.requestFocus()
    @filter_text.selectRange( 0 , @filter_text.getText().length  )
  end

end
