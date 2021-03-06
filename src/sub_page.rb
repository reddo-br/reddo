# -*- coding: utf-8 -*-

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
require 'sub_pref_menu_items'

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
import 'javafx.scene.text.Text'
import 'javafx.application.Platform'
import 'javafx.util.StringConverter'
class SubPage < Page
  include SubPrefMenuItems

  SORT_TYPES = [ # [ "注目" , "hot" , nil ],
                # [ "新着" , "new" , nil ],
                
                [ "上昇中","rising" , nil],
                
                [ "トップ(時)" , "top" , :hour ],
                [ "トップ(日)" , "top" , :day  ],
                [ "トップ(週)" , "top" , :week],
                [ "トップ(月)" , "top" , :month],
                [ "トップ(年)" , "top" , :year ],
                [ "トップ(全)" , "top" , :all  ],
                
                [ "論争中(時)" , "controversial" , :hour ],
                [ "論争中(日)" , "controversial" , :day  ],
                [ "論争中(週)" , "controversial" , :week  ],
                [ "論争中(月)" , "controversial" , :month],
                [ "論争中(年)" , "controversial" , :year ],
                [ "論争中(全)" , "controversial" , :all  ],
                
               ]
  
  OPTION_SORT_TYPES_DEFAULT = SORT_TYPES.index{|e| e[0] == "トップ(週)" }

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

      @sub_menu_button.getItems.add( SeparatorMenuItem.new )
      sub_css_menu = Menu.new("subredditのcss(旧UI系)再現")
      create_sub_pref_menu_items( sub_css_menu , @page_info[:name] )
      @sub_menu_button.getItems.add( sub_css_menu )
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
      start_reload( add:true )
    }
    @sort_button_area_left.getChildren().addAll(@subm_count_label,
                                                @subm_add_button ,
                                                Label.new(" "),
                                                Separator.new(Orientation::VERTICAL) )

    
    # @sort_button_area.setStyle("-fx-margin: 3px 3px 0px 3px")
    @sort_buttons = []

    @current_sort_other = SORT_TYPES[OPTION_SORT_TYPES_DEFAULT]

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
      if not @on_clearing
        display_subms
      end
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
      if not @on_clearing
        display_subms
      end
    }
    filters << @filter_read = ToggleButton.new("新着コメ")
    @filter_read.setOnAction{
      if not @on_clearing
        display_subms
      end
    }

    @filter_area.getChildren().addAll( filters )
    
    BorderPane.setAlignment( @filter_area , Pos::CENTER_LEFT )
    @filter_and_search_bar.setLeft( @filter_area )


    # google_search欄ににサムネ表示切り替えを追加することに
    @google_search_area = HBox.new
    @google_search_area.setAlignment(  Pos::CENTER_RIGHT )
    thumb_switch_widgets = []
    thumb_switch_widgets  << Label.new("サムネ:")
    
    thumb_switch_buttons = []
    thumb_switch_buttons << @no_thumb_button = ToggleButton.new("無")
    thumb_switch_buttons << @small_thumb_button = ToggleButton.new("小")
    thumb_switch_buttons << @medium_thumb_button = ToggleButton.new("中")
    @thumb_button_group = ToggleGroup.new()
    thumb_switch_buttons.each{|b| b.setToggleGroup( @thumb_button_group )}
    @list_style = pref['list_style'].to_s.to_sym # tablecellが描画時に読みこむのにファイルアクセスは時間がかかる
    thumb_default_button = case @list_style
                           when :medium_thumb
                             @medium_thumb_button
                           when :no_thumb
                             @no_thumb_button
                           else
                             @small_thumb_button
                           end
    Util.toggle_group_set_listener_force_selected( @thumb_button_group ,
                                                   thumb_default_button){|btn| set_thumb_size }
    App.i.make_pill_buttons( thumb_switch_buttons )
    thumb_switch_widgets.concat( thumb_switch_buttons )
    thumb_switch_widgets << Label.new(" ")
    
    @google_search_area.getChildren.addAll( thumb_switch_widgets )

    if not @is_multireddit
      # @google_search_area = HBox.new

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
      @google_search_area.getChildren.addAll( parts )
      
    end # is not multireddit
    BorderPane.setAlignment( @google_search_area , Pos::CENTER_RIGHT )
    @filter_and_search_bar.setRight( @google_search_area )

    getChildren.add( @filter_and_search_bar )
    
    #### table
    calc_digit_width

    @table = TableView.new
    
    rank_column = TableColumn.new
    rank_column.setText("ﾗﾝｸ")
    rank_column.setMaxWidth(@@digit_width_4)
    rank_column.setMinWidth(@@digit_width_4)
    rank_column.setPrefWidth(@@digit_width_4)
    rank_column.setResizable(false)
    rank_column.setSortable(false)
    #rank_column.set_cell_value_factory{|cdf|
      #rank = @table.getItems().indexOf( cdf.getValue()) + 1
      # SimpleIntegerProperty.new( rank )
    #}
    rank_column.set_cell_value_factory( MapValueFactory.new( :reddo_rownum ))
    rank_column.set_cell_factory{|col| NumberCell.new }

    @vote_column = TableColumn.new
    @vote_column.set_cell_value_factory{|cdf|
      # p cdf.getValue() # Redd::Objects::Submission
      # SimpleObjectProperty.new( cdf.getValue() ) # 全データを渡す これでいいか
      SimpleObjectProperty.new( cdf.getValue() )

    }
    @vote_column.set_cell_factory{|col| VoteCell.new(self) }
    # widthはadjust_column_widthで
    @vote_column.setResizable( false)
    @vote_column.setSortable(false)

    score_column = TableColumn.new
    score_column.setText("ｽｺｱ")
    score_column.setMinWidth( @@digit_width_6 )
    score_column.setMaxWidth( @@digit_width_6 )
    score_column.setPrefWidth( @@digit_width_6 )
    #score_column.set_cell_value_factory( MapValueFactory.new( :reddo_score ))
    #score_column.set_cell_factory{|col| NumberCell.new }
    score_column.set_cell_value_factory{ |cdf| SimpleObjectProperty.new( cdf.getValue()) }
    score_column.set_cell_factory{|col| ScoreNumberCell.new }

    @thumb_column = TableColumn.new
    @thumb_column.setText("画像")
    # widthはadjust_column_widthで
    # @thumb_column.set_cell_value_factory( MapValueFactory.new(:reddo_thumbnail_decoded))
    @thumb_column.set_cell_value_factory{ |cdf| SimpleObjectProperty.new( cdf.getValue()) }
    @thumb_column.set_cell_factory{|col| ThumbCell.new(self) }
    @thumb_column.setResizable(false)
    @thumb_column.setSortable(false)

    @subreddit_column = TableColumn.new
    @subreddit_column.setText("Sub")
    @subreddit_column.setMinWidth( @@subreddit_name_width )
    @subreddit_column.setMaxWidth( @@subreddit_name_width )
    @subreddit_column.setPrefWidth( @@subreddit_name_width )
    @subreddit_column.set_cell_value_factory( MapValueFactory.new( :subreddit ) )
    @subreddit_column.set_cell_factory{|col| SubredditCell.new }
    @subreddit_column.setSortable(false)
    
    comm_column = TableColumn.new
    comm_column.setText("ｺﾒﾝﾄ数")
    comm_column.setMinWidth( @@digit_width_5 )
    comm_column.setMaxWidth( @@digit_width_5 )
    comm_column.setPrefWidth( @@digit_width_5 )
    comm_column.set_cell_value_factory( MapValueFactory.new( :num_comments ))
    comm_column.setSortable(false)
    comm_column.set_cell_factory{|col| NumberCell.new }

    comm_new_column = TableColumn.new
    comm_new_column.setText("新着")
    comm_new_column.setMinWidth( @@digit_width_5 )
    comm_new_column.setMaxWidth( @@digit_width_5 )
    comm_new_column.setPrefWidth( @@digit_width_5)
    comm_new_column.set_cell_value_factory( MapValueFactory.new( :reddo_num_comments_new ))
    comm_new_column.setSortable(false)
    comm_new_column.set_cell_factory{|col| NumberCell.new }

    title_column = TableColumn.new
    title_column.setText("タイトル")
    title_column.set_cell_value_factory{ |cdf| SimpleObjectProperty.new( cdf.getValue()) }
    title_column.set_cell_factory{|col| 
      multi = @url_handler.path_is_multireddit( @page_info[:name])
      TitleCell.new(self , col, show_subreddit:multi , artificial_bold:@artificial_bold) 
    }

    
    title_column.prefWidthProperty().bind( @table.widthProperty.subtract(rank_column.widthProperty).subtract( @vote_column.widthProperty).subtract( score_column.widthProperty ).subtract(@thumb_column.widthProperty).subtract(@subreddit_column.widthProperty).subtract( comm_column.widthProperty ).subtract( comm_new_column.widthProperty ).subtract(20))

    title_column.setSortable(false)

    # @table.setColumnResizePolicy(TableView::CONSTRAINED_RESIZE_POLICY)
    @table.setPrefHeight( 10000 )
    @table.getColumns.setAll( rank_column , @vote_column , score_column , comm_column , comm_new_column , @thumb_column , @subreddit_column , title_column)
    
    adjust_column_width

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

    @table_stack = StackPane.new
    @table_stack.getChildren().add( @table )
    getChildren().add( @table_stack )

    @table_bottom_mark = Label.new
    @table_bottom_mark.setText("↓追加ロード")
    @table_bottom_mark.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::STRONG_RED}; -fx-opacity:0.8;-fx-background-radius: 6 6 6 6;-fx-padding:6 6 6 6;")
    @table_bottom_mark.setOnMouseClicked{|ev|
      key_add
    }
    StackPane.setAlignment( @table_bottom_mark , Pos::BOTTOM_RIGHT )
    StackPane.setMargin( @table_bottom_mark , Insets.new(8,30,8,8) )
    @table_stack.add( @table_bottom_mark )
    set_bottom_mark_state(false)
    
    # 本体
    self.class.setMargin( @button_area , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @sort_button_area , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @filter_and_search_bar , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @table_stack , Insets.new(3.0, 3.0 , 0 , 3.0) )
    
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

    # 新ホイールスクロール機構の設定
    @wheel_base_amount = App.i.pref["scroll_v2_wheel_amount"] || 100
    @wheel_accel_max   = App.i.pref["scroll_v2_wheel_accel_max"] || 2.5
    @smooth_scroll     = App.i.pref["scroll_v2_smooth"]

    prepare_smooth_scroll_thread

    start_reload
  end # initialize
  attr_reader :is_user_submission_list
  attr_reader :pref , :list_style , :table

  FRAME_INT = 0.025
  def prepare_smooth_scroll_thread
    if @smooth_scroll
      @smooth_scroll_queue = []
      @smooth_scroll_queue_mutex = Mutex.new
      @smooth_scroll_thread = Thread.new{
        loop{
          move = nil
          @smooth_scroll_queue_mutex.synchronize{
            move = @smooth_scroll_queue.shift
          }
          if move == "focus_top"
            Platform.runLater{
              select_row( get_scroll_top ) if not selection_is_in_view(true)
            }
          elsif move
            if vf = get_virtual_flow
              Platform.runLater{
                vf.adjustPixels( move )
              }
            end
          end
          sleep( FRAME_INT )
        }
      }
    end
  end

  def calc_digit_width
    @@digit_width_4 ||= 
      [App.i.calc_string_width( "0000" , "-fx-font-size:150%;") , 40 ].max + 8
    @@digit_width_5 ||= 
      [App.i.calc_string_width( "00000" ,"-fx-font-size:150%;") , 40 ].max + 8
    @@digit_width_6 ||= 
      [App.i.calc_string_width( "000000" ,"-fx-font-size:150%;"), 40 ].max + 8
    @@subreddit_name_width ||=
      [App.i.calc_string_width( "wwwwwwwwww" ,"-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::STRONG_GREEN)};"), 40 ].max + 8
  end

  def set_bottom_mark_state( visible = nil )
    if visible == nil
      visible = is_table_bottoming_out
    end
    @table_bottom_mark.setVisible(visible)
  end

  def thumb_width
    if @list_style == :medium_thumb
      140
    elsif @list_style == :no_thumb
      0
    else
      74
    end
  end
  def thumb_height
    if @list_style == :medium_thumb
      140
    elsif @list_style == :no_thumb
      0
    else
      54
    end
  end
  def adjust_column_width
    if @list_style == :no_thumb

      #if @table.getColumns.contains( @thumb_column )
      #  @table.getColumns.remove( @thumb_column )
      #end
      
      @thumb_column.setMinWidth( 0 )
      @thumb_column.setMaxWidth( 0 )
      @thumb_column.setVisible(false)

      @vote_column.setMinWidth( 0 )
      @vote_column.setPrefWidth( 75 )

      if @is_multireddit
        @subreddit_column.setVisible(true)
        @subreddit_column.setMaxWidth( 100 )
        @subreddit_column.setMinWidth( 100 )
      else
        @subreddit_column.setVisible(false)
        @subreddit_column.setMaxWidth( 0 )
        @subreddit_column.setMinWidth( 0 )
      end 
    else

      #if not @table.getColumns.contains( @thumb_column)
      #  @table.getColumns.add( 5 , @thumb_column )
      #end
      @thumb_column.setVisible(true)
      @thumb_column.setMinWidth( thumb_width + 6)
      @thumb_column.setMaxWidth( thumb_width + 6)

      @subreddit_column.setVisible(false)
      @subreddit_column.setMaxWidth( 0 )
      @subreddit_column.setMinWidth( 0 )
      
      @vote_column.setMinWidth( 0 )
      @vote_column.setPrefWidth( 40 )

    end
  end
  def set_thumb_size
    case @thumb_button_group.getSelectedToggle
    when @no_thumb_button
      @pref['list_style'] = 'no_thumb'
    when @small_thumb_button
      @pref['list_style'] = nil
    when @medium_thumb_button
      @pref['list_style'] = 'medium_thumb'
    end
    @list_style = @pref['list_style'].to_s.to_sym
    adjust_column_width
    # 再描画
    # display_subms

    if vf = get_virtual_flow
      vf.recreateCells() # javafx9ではない？
    end

    # @table.lookupAll(".thumb-cell").each{|c| c.adjust_image_size}
    # @table.lookupAll(".vote-cell").each{|c| c.adjust_direction }
    # @table.lookupAll(".title-cell").each{|c| c.adjust}
  end

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
        if @sub_info[:subreddit_type] == 'user'
          @sub_info[:display_name] + "[ユーザー投稿]"
        else
          @sub_info[:display_name]
        end
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
          set_tab_icon2_url( @sub_info[:icon_img] ) if @sub_info[:icon_img].to_s.length > 0
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
    @smooth_scroll_thread.kill if @smooth_scroll_thread
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

  def start_reload(add:false , count:nil)
    count ||= App.i.pref['sub_number_of_posts_to_get']
    $stderr.puts "取得数 #{count}"
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
            rpath = path + if path =~ /\/$/
                             ""
                           else
                             "/"
                           end + "rising.json"
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
            rpath = path + if path =~ /\/$/
                             ""
                           else
                             "/"
                           end + "gilded.json"
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
          
          if obj[:link_flair_text]
            obj[:link_flair_text_decoded] = Html_entity.decode( obj[:link_flair_text] ) 
          end
          if obj[:author_flair_text]
            obj[:author_flair_text_decoded] = Html_entity.decode( obj[:author_flair_text] )
          end
          [ [:link_flair_richtext , :link_flair_richtext_decoded] ,
            [:author_flair_richtext , :author_flair_richtext_decoded] ].each{
            |key_from,key_to|
            
            if obj[key_from]
              rd = obj[key_from].map{|h|
                h2 = h.dup
                if h2[:e] == 'text'
                  h2[:t] = Html_entity.decode(h[:t])
                end
                h2
              }
              obj[key_to] = rd
            end
          }
          
          tu , tw , th = Util.decoded_thumbnail_url(obj)
          obj[:reddo_thumbnail_decoded] = tu
          if tw and th
            obj[:reddo_thumbnail_ratio] = th / tw.to_f
          end

          # previewは別に取る
          if LINK_FOR_PREVIEW_RXP.find{|r|
              file = Addressable::URI.parse( obj[:url] ).path
              file =~ r
            } or
              obj[:reddo_thumbnail_decoded] == nil
            tu , tw , th = Util.find_submission_preview( obj,
                                                         min_width:216,
                                                         prefer_large:true)
            if tu
              ra = th / tw.to_f
              if 1.0 < ra and ra <= 3.0 # 縦長すぎるのは使わない,thumbで間に合うのも使わない
                # 2019 実はraは2倍以上にはならない。この値は表示上の推奨値のようだ…
                tu = Html_entity.decode(tu) if tu
                obj[:reddo_preview] = tu
                if tw and th
                  obj[:reddo_preview_ratio] = ra
                end
              end # ra
            end # tu
          end
          
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

  LINK_FOR_PREVIEW_RXP = [ /\.jpg$/ , /\.png$/,/\.gif$/,/\.avi$/ , /\.mp4$/ , /^https?:\/\/imgur\.com\// ]
                     
  
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
      # $stderr.puts "■get_sub_url: #{au.to_s}"
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
      # virtualflow関係のhookはここで入れる、最初はvfが出きてないっぽいので
      if App.i.pref['scroll_v2_enable']
        set_scroll_amount()
      end
      set_wheel_event_handler_to_more_post

      set_bottom_mark_state # とりあえず更新前状態で判定する
      set_virtualflow_listeners_to_set_bottom_mark
      set_scrollbar_listeners_to_set_bottom_mark # javafx8 tableのscrollbarは実際にitemがあふれるまで取れない
      ThumbCell.shrink_cache
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

  def get_scrollbar
    scrs = @table.lookupAll(".scroll-bar").to_a
    if scrs.length > 0
      scrs[0]
    else
      nil
    end
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

  def get_inview_height_forward
    if vf = get_virtual_flow
      cell = vf.getLastVisibleCellWithinViewPort()
      if cell
        cell.getLayoutY + cell.getHeight
      else
        vf.getHeight
      end
    else
      nil
    end
  end

  def get_inview_height_backward
    if vf = get_virtual_flow
      cell = vf.getFirstVisibleCellWithinViewPort()
      if cell
        vf.getHeight - cell.getLayoutY
      else
        vf.getHeight
      end
    else
      nil
    end
  end

  def is_table_bottoming_out
    bot = get_scroll_bottom
    # $stderr.puts "is_table_bottoming_out: bot:#{bot}"
    if bot
      size = @table.getItems().size

      # $stderr.puts "is_table_bottoming_out size:#{size}"

      bot == (size - 1)
    else
      # false
      true # アイテムが無いのをonにしてみる、起動直後対策
    end
  end

  # 一回でadjustPixelsしようとするとなぜかズレるので旧方式を使う もっともこれでもまだズレるが
  def screen_scroll_not_animate( forward , do_focus_top = false , ratio = 1.0 )
    # vf_scroll_animate_stop
    if @list_style == :medium_thumb and ratio > 0.7
      ratio = 0.7
    end

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

      target = first + amount
      select_row( target ) if do_focus_top
      @table.scrollTo( target )
      # puts "screen_scroll(not anime) target=#{target}"
      nil
    end
  end

  def screen_scroll_animate( forward , do_focus_top = false , ratio = 1.0)
    if vf = get_virtual_flow
      h = if forward
            get_inview_height_forward
          else
            get_inview_height_backward
          end
      h ||= vf.getHeight
      
      amount = if forward
                 h * ratio
               else
                 h * ratio * -1
               end
      # puts "screen_scroll height=#{vf.getHeight} h=#{h} ratio=#{ratio} amount=#{amount} "
      if @smooth_scroll
        vf_scroll_animate( amount - 1, 300 , vf , do_focus_top)
      else
        # あまりにもずれる
        dev = case @list_style
              when :medium_thumb
                0.7
              when :no_thumb
                1
              else
                0.9
              end

        vf.adjustPixels( amount * dev)
        select_row( get_scroll_top ) if do_focus_top and not selection_is_in_view(true)
      end
    else
      nil
    end
  end

  def screen_scroll(forward , do_focus_top = false , ratio = 1.0)
    if @smooth_scroll
      screen_scroll_animate(forward , do_focus_top , ratio)
    else
      screen_scroll_not_animate(forward , do_focus_top , ratio)
    end
  end

  def set_scroll_amount( )
    if vf = get_virtual_flow
      vf.setOnScroll{|ev|
        # $stderr.puts "sub_page scrollイベント"
        if ev.eventType == ScrollEvent::SCROLL
          table_wheel_scroll( ev , vf )
        end
        ev.consume
      }
    end
  end

  def table_wheel_scroll( ev , vf)
    vf ||= get_virtual_flow
    mt = Time.now.to_f * 1000
    accel = if @last_scroll_time_msec
              dt = mt - @last_scroll_time_msec
              # 250000 / (dt ** 2 ) # 500 ** 2 /
              400 / dt
            else
              1
            end
    if accel > @wheel_accel_max
      accel = @wheel_accel_max
    elsif accel < 1
      accel = 1
    end

    dir = if ev.getDeltaY < 0
            1
          else
            -1
          end

    amount = @wheel_base_amount * accel * dir

    $stderr.puts "sub wheel scroll: dt=#{dt} accel=#{accel} amout=#{amount}"

    if @smooth_scroll
      #if @last_animation_started and (mt - @last_animation_started) < FRAME_INT * 1000
      #  puts "wheel event skip"
      #else
      #  @last_animation_started = mt
        vf_scroll_animate( amount , 150 , vf)
      #end
    else
      vf.adjustPixels( amount )
    end
    @last_scroll_time_msec = mt
  end

  def vf_scroll_animate( amount , duration , vf , do_focus_top = false)
    times = (duration / (FRAME_INT * 1000.0)).to_i
    step = amount.to_i / times
    step_mod = amount % times
    # puts "vf_scroll_animate: amount=#{amount} step=#{step} times=#{times} step_mod=#{step_mod}"
    @smooth_scroll_queue_mutex.synchronize{
      @smooth_scroll_queue.clear
      times.times{
        step1 = if step_mod > 0
                  step_mod -=1
                  step + 1
                else
                  step
                end
        @smooth_scroll_queue << step1
      }

      if do_focus_top
        @smooth_scroll_queue << "focus_top"
      end
    }
  end
  
  def vf_scroll_animate_stop
    @smooth_scroll_queue_mutex.synchronize{
      @smooth_scroll_queue.clear
    }
  end

  def set_wheel_event_handler_to_more_post
    if not @wheel_event_handler_to_more_post_is_prepared
      @wheel_event_handler_to_more_post_is_prepared = true
      target = [ get_virtual_flow , @table ] # アイテムが無い場合はtableviewでイベントを受ける
      target.each{|vf|
        if vf
          vf.addEventHandler( ScrollEvent::SCROLL ){|ev|

            mt = Time.now
            if is_table_bottoming_out and ev.getDeltaY < 0
              if not @wheel_load_last_check_time or @wheel_load_last_check_time < mt - 0.4
                key_add
              end
            end
            @wheel_load_last_check_time = mt
            
          }
        end
      }
    end
  end

  def set_virtualflow_listeners_to_set_bottom_mark
    if not @vf_listener_to_bm
      if vf = get_virtual_flow


        # heightPropertyはタイミング的に早い。is_bottoming_outでチェックするとまだitemが表示されない
        #vf.heightProperty().addListener{|ev| 
        #  $stderr.puts "●vf.heightProperty listener called"
        #  set_bottom_mark_state
        #}

        # java8にない
        #vf.positionProperty().addListener{|ev| 
        #  puts "positionProperty"
        #  set_bottom_mark_state
        #}
        
        @vf_listener_to_bm = true
      end
    end
  end

  # うまくいかない
  def set_scrollbar_listeners_to_set_bottom_mark
    if not @scrollbar_listener_to_bm
      
      if scr = get_scrollbar
        @scrollbar_listener_to_bm = true
        
        scr.valueProperty.addListener{|ev|
          # $stderr.puts "valueProperty listener called"
          set_bottom_mark_state
        }
        scr.visibleAmountProperty.addListener{|ev|
          # $stderr.puts "■visibleAmountProperty listener called"
          set_bottom_mark_state
        }
        scr.maxProperty.addListener{|ev|
          # $stderr.puts "■maxAmountProperty listener called"
          set_bottom_mark_state
        }
        # scr.visibleProperty.addListener{|ev|
        #   $stderr.puts "■visibleProperty listener called"
        #   set_bottom_mark_state
        # }
      else
        $stderr.puts "スクロールバーがない"
        # とりあえずbottom markをonにしておく
        set_bottom_mark_state(true)
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
        subm[:link_flair_text_decoded].to_s.downcase.index(word)
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
                               :account_name => comm_account ,
                               :subreddit => item[:subreddit]
                             } ,
                             set_focus)
    
  end

  class VoteCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl
    STYLE_BASE = "-fx-font-size:100%;"
    def initialize(page)
      super()
      getStyleClass().add("vote-cell")
      
      @page = page
      @upvote_button = ToggleButton.new("▲")
      @upvote_button.setStyle(STYLE_BASE)
      @upvote_button.getStyleClass().add("upvote-button")
      @downvote_button = ToggleButton.new("▼")
      @downvote_button.setStyle(STYLE_BASE)
      @downvote_button.getStyleClass().add("downvote-button")

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

      @vbox = VBox.new
      @hbox = HBox.new
      @vbox.setAlignment( Pos::CENTER_LEFT )
      @hbox.setAlignment( Pos::CENTER_LEFT )

      adjust_direction
    end
    
    def adjust_direction
      list_style = @page.list_style
      if @current_list_style != list_style
        if list_style == :no_thumb
          if not @hbox.getChildren().contains( @upvote_button )
            App.i.make_pill_buttons( [ @upvote_button , @downvote_button ] )
            @hbox.getChildren().add( @upvote_button )
            @hbox.getChildren().add( @downvote_button )
          end
          if getGraphic != @hbox
          setGraphic( @hbox )
          end
        else
          if not @vbox.getChildren().contains( @upvote_button )
            App.i.make_pill_buttons( [ @upvote_button , @downvote_button ] , true )
            @vbox.getChildren().add( @upvote_button )
            @vbox.getChildren().add( @downvote_button )
          end
          if getGraphic != @vbox
            setGraphic( @vbox )
          end
        end
        @current_list_style = list_style
      end
    end

    def updateItem( data , is_empty_col )
      sub_page = @page
      adjust_direction
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
    
    def initialize( sub_page )
      super()
      getStyleClass().add("thumb-cell")
      setPadding( Insets.new( 2, 2, 2, 2 ))
      @sub_page = sub_page

      @image_view = ImageView.new
      @image_view.setSmooth(true)
      # @image_view.setCache(true)
      @image_view.setPreserveRatio(true)
      adjust_image_size

      setAlignment( Pos::CENTER )

      setGraphic( @image_view)
    end
    @@cache = {}
    def self.shrink_cache
      $stderr.puts "thumb cache length: #{@@cache.length}"
      if @@cache.length > 100
        n = Time.now.to_i - 1800
        @@cache.delete_if{|k,v|
          if v[1] and (v[1] < n)
            $stderr.puts "remove cache:#{k}:#{v}"
            true
          else
            false
          end
        } # たぶんスレッドセーフ
      end
    end

    def adjust_image_size(img_type = :thmub , data = nil)
      list_style = @sub_page.list_style
      
      image_width = @sub_page.thumb_width
      image_height = @sub_page.thumb_height
      @image_view.setFitWidth( image_width )

      # :medium_thumbなど可変列モードでは毎回替えなければいけない
      if list_style == :medium_thumb

        if img_type == :mark
          setPrefHeight(nil)
          @image_view.setFitHeight( 50 )
        elsif data
          ratio = data[:reddo_preview_ratio] || data[:reddo_thumbnail_ratio]
          if ratio
             setPrefHeight( image_width * ratio + 6)
            # self.setMaxHeight( image_width * ratio ) # 効かない
            if ratio >= 2.0
              @image_view.setFitHeight( image_width * ratio )
            else
              @image_view.setFitHeight( nil )
            end
          else
            setPrefHeight( nil )
            @image_view.setFitHeight( nil )
          end
        else # dataなし 初期など
          setPrefHeight( nil )
          @image_view.setFitHeight( nil )
        end
      else # :medium_thumb以外では、モードが変わった時だけサイズを替える
        
        if @current_list_style != list_style or @current_img_type != img_type
          
          setPrefHeight(nil)
          if img_type == :mark
            @image_view.setFitHeight( 50 )
          elsif list_style == :""
            @image_view.setFitHeight( image_height )
          elsif list_style == :no_thumb
            @image_view.setFitHeight( 1 )
          end
          
          if list_style == :no_thumb
            setMinWidth( 1 )
          else
            setMinWidth( image_width + 6)
          end

        end

      end # medium or others
      
      @current_list_style = list_style
      @current_img_type = img_type
    end

    def size_for_image_obj
      list_style = @sub_page.list_style
      image_width = @sub_page.thumb_width
      image_height = @sub_page.thumb_height
      if list_style == :""
        [ image_width , image_height ]
      elsif list_style == :medium_thumb
        [ image_width , 0 ]
      else
        nil
      end
    end
    
    def updateItem( data , is_empty_col )
      @obj = data
      if data


        
        if data[:reddo_thumbnail_decoded] and not is_empty_col and not data[:spoiler]
          adjust_image_size( :thumb , data )
          url = if @sub_page.list_style == :medium_thumb 
                  data[:reddo_preview] || data[:reddo_thumbnail_decoded]
                else
                  data[:reddo_thumbnail_decoded] || data[:reddo_preview]
                end
          # p url
          # i = @@cache[ url ] || Image.new( url, @image_width, @image_height ,true,true,true) # ratio,smooth,background # なんでこれ止めたんだっけ？ リサイズ処理がしょぼいから？
          i,t=nil,nil
          if false # App.i.pref["image_reduction_with_image_object"] and wh = size_for_image_obj
            # Imageクラスの縮小はいまいち、別のライブラリを使うべき
            i,t = ( @@cache[ [url , wh] ] ||= [ Image.new( url ,wh[0],wh[1],true,true,true) , nil ] )
            @@cache[ [url,wh] ][1] = Time.now.to_i
            @image_view.setFitWidth(nil)
            @image_view.setFitHeight(nil)
            @image_view.setSmooth(false)
          else
            i,t = ( @@cache[ [url , :general] ] ||= [ Image.new( url ,true) , nil ] )
            @@cache[ [url,:general] ][1] = Time.now.to_i
            # @image_view.setSmooth(true)
          end
          @image_view.setImage( i )

        else
          adjust_image_size( :mark )
          i,t = if data[:is_self]
                  @@cache[ "is_self" ] ||= [Image.new( App.res( "/res/thumb_text.png")),nil]
                else
                  @@cache[ "none" ] ||= [Image.new( App.res( "/res/thumb_none.png")),nil]
               end
          @image_view.setImage( i )
          
        end
      else # 空の列
        adjust_image_size( :thumb )
        @image_view.setImage(nil)
      end
      
    end
    
    def resize_keep_ratio( target_width , target_height , width , height )

    end

  end
  
  class SubredditCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl

    def initialize
      super()
      @sub = Label.new
      @sub.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::STRONG_GREEN)};-fx-padding:0 6px 0 0;")
      setAlignment( Pos::CENTER_LEFT )
      setGraphic(@sub)
    end

    def updateItem( data , is_empty_col )
      if data and not is_empty_col
        @sub.setText(data.to_s)
      else
        @sub.setText("")
      end
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

    @@cache = {} # emoji

    def set_color_normal
      color = if App.i.pref['use_dark_theme']
                'white'
              else
                'black'
              end

      @subm_title.setStyle( "-fx-fill:#{color}; -fx-font-size:115%; -fx-word-wrap:break-word; #{App.i.fx_bold_style(color)}")
      
      if @show_subreddit
        @subreddit.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::STRONG_GREEN)};-fx-padding:0 6px 0 0;")
      end

      @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_BLUE};")
      @gilded_s.setStyle("-fx-text-fill:#{App.i.theme::COLOR::HTML_TEXT_THIN};")
      @gilded_p.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_BLUE};")
      @gilded.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_YELLOW};")
      
      @crosspost.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::STRONG_GREEN)};-fx-padding:0 6px 0 0;")
      
    end

    def set_color_reverse
      color = if App.i.pref['use_dark_theme']
                'black'
              else
                'white'
              end

      @subm_title.setStyle( "-fx-fill:#{color}; -fx-font-size:115%; -fx-word-wrap:break-word; #{App.i.fx_bold_style(color)}")
      
      if @show_subreddit
        @subreddit.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::THIN_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::THIN_GREEN)};-fx-padding:0 6px 0 0;")
      end

      @author.setStyle("-fx-text-fill:#{App.i.theme::COLOR::THIN_BLUE};")
      @gilded_s.setStyle("-fx-text-fill:#{App.i.theme::COLOR::HTML_TEXT_THIN};")
      @gilded_p.setStyle("-fx-text-fill:#{App.i.theme::COLOR::THIN_BLUE};")
      @gilded.setStyle("-fx-text-fill:#{App.i.theme::COLOR::THIN_YELLOW};")
      
      @crosspost.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::THIN_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::THIN_GREEN)};-fx-padding:0 6px 0 0;")
      
    end
    
    def initialize(page , col = nil , artificial_bold:false, show_subreddit:false)
      super()
      getStyleClass().add("title-cell")
      
      @page = page
      @show_subreddit = show_subreddit
      
      @@emoji_height ||= App.i.calc_string_height( "0" , "-fx-font-size:100%;")
      
      # @subm_title = Label.new
      @subm_title = Text.new
      
      if @show_subreddit
        @subreddit = Label.new
        @subreddit.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::STRONG_GREEN};#{App.i.fx_bold_style(App.i.theme::COLOR::STRONG_GREEN)};-fx-padding:0 6px 0 0;")
        @subreddit.setWrapText(false)
      end

      @nsfw = Label.new("NSFW")
      # @nsfw.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::STRONG_RED}")
      @nsfw.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};#{App.i.fx_bold_style(App.i.theme::COLOR::REVERSE_TEXT)}; -fx-background-color:#{App.i.theme::COLOR::STRONG_RED}")
      @nsfw.setWrapText(false)

      @spoiler = Label.new("Spoiler")
      @spoiler.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};#{App.i.fx_bold_style(App.i.theme::COLOR::REVERSE_TEXT)}; -fx-background-color:#{App.i.theme::COLOR::STRONG_RED}")
      @spoiler.setWrapText(false)

      @link_flair = HBox.new
      @link_flair.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::HTML_TEXT_THIN};")
      @link_flair.setMaxWidth(150)

      @auto_banned = Label.new()
      @auto_banned.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}; -fx-background-color:#{App.i.theme::COLOR::STRONG_RED};")
      @auto_banned.setWrapText(false)

      @datetime = Label.new
      @datetime.setStyle( "-fx-padding:0 6px 0 0;")
      @datetime.setWrapText(false)

      @sticky = Label.new("Announcement")
      @sticky.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};#{App.i.fx_bold_style(App.i.theme::COLOR::REVERSE_TEXT)}; -fx-background-color:#{App.i.theme::COLOR::STRONG_GREEN}")
      @sticky.setWrapText(false)

      @locked = Label.new("Locked")
      @locked.setStyle("-fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT};#{App.i.fx_bold_style(App.i.theme::COLOR::REVERSE_TEXT)}; -fx-background-color:#{App.i.theme::COLOR::STRONG_YELLOW}")
      @locked.setWrapText(false)

      @author = Label.new
      @author.setWrapText(false)
      
      @user_flair = HBox.new
      @user_flair.setStyle( "-fx-border-color:#{App.i.theme::COLOR::BASE}; -fx-border-width: 1 1 1 1" )
      @user_flair.setMaxWidth( 300 )

      @gilded_s = Label.new
      @gilded_s.setWrapText(false)

      @gilded = Label.new
      @gilded.setWrapText(false)

      @gilded_p = Label.new
      @gilded_p.setWrapText(false)

      @views = Label.new
      @views.setWrapText(false)
      # @views.setStyle("#{App.i.fx_bold_style(color)}")

      @domain = Label.new
      @domain.setWrapText(false)
      @domain.setStyle("-fx-padding:0 6px 0 6px;")
      #####

      @crosspost = Label.new
      @crosspost.setWrapText(false)
      
      # setPrefHeight( 1 ) # これをやるとwrapできなくなる
      
      # todo:反転カラーを動的に設定するには、結局TableCell#updateSelectedで
      # いちいち設定するしかないだろう
      set_color_normal
      
      @hbox = HBox.new()
      # @hbox = FlowPane.new(Orientation::HORIZONTAL)
      @hbox.setAlignment( Pos::CENTER_LEFT )
      
      @hbox.getChildren().add( @auto_banned )
      @hbox.getChildren().add( @datetime )
      @hbox.getChildren().add( @author )
      @hbox.getChildren().add( @user_flair )
      @hbox.getChildren().add( @gilded_s )
      @hbox.getChildren().add( @gilded )
      @hbox.getChildren().add( @gilded_p )

      @hbox2 = HBox.new()
      @hbox2.setAlignment( Pos::CENTER_LEFT )
      @hbox2.getChildren().add( @subreddit ) if @show_subreddit
      @hbox2.getChildren().add( @nsfw )
      @hbox2.getChildren().add( @spoiler )
      @hbox2.getChildren().add( @locked )
      @hbox2.getChildren().add( @sticky )
      @hbox2.getChildren().add( @link_flair )
      @hbox2.getChildren().add( @domain )
      @hbox2.getChildren().add( @crosspost )
      @hbox2.getChildren().add( @views )
      
      @box = VBox.new
      @box.setAlignment( Pos::TOP_LEFT )

      @box.getChildren().add( @subm_title )

      adjust
      # @box.getChildren().add( @hbox2 )
      # @box.getChildren().add( @hbox )

      # box.prefHeightProperty().bind( self.heightProperty()) # wrapしなくなる
      # self.heightProperty().bind( box.heightProperty())
      # self.heightProperty().bind( box.heightProperty())
      # @box.setPrefHeight(70) # 固定されてしまう -> あとでまた変える
      # @subm_title.heightProperty().addListener{

      widthProperty().addListener{|ev|
        if @page.list_style == :no_thumb
          @subm_title.setWrappingWidth( 0 )
        else
          @subm_title.setWrappingWidth( getWidth() - 4)
        end
      }

      setGraphic( @box )
    end

    def adjust
      list_style = @page.list_style
      if @current_list_style != list_style
        if @page.list_style == :no_thumb
          # @hbox2.setVisible(false)
          # @hbox.setVisible(false)
          @box.setAlignment(Pos::CENTER_LEFT )
          
          @box.getChildren.remove( @hbox2 )
          @box.getChildren.remove( @hbox )
        else
          @box.setAlignment(Pos::TOP_LEFT )
          if not @box.getChildren.contains( @hbox2 )
            @box.getChildren.add( @hbox2 )
            @box.getChildren.add( @hbox )
          end
        end

        if list_style == :no_thumb
          @subm_title.setWrappingWidth( 0 )
        else
          @subm_title.setWrappingWidth( getWidth() - 4)
        end
        @current_list_style = list_style
      end
    end

    def set_richtext_to_box( box, richtext , text , color , bgcolor ,
                             color_default , bgcolor_default , base_style)
      style_tx = nil
      if bgcolor.to_s.length > 0 # :*_flair_background_color 空白もある
        style_bg = "-fx-background-color:#{ bgcolor };"
        box.setStyle( style_bg + base_style)
        if color == 'light'
          style_tx = "-fx-text-fill:#eeeeee;"
        elsif color == 'dark'
          style_tx = "-fx-text-fill:#222222;"
        else
          style_tx = "-fx-text-fill:#{color_default};" if color_default
        end
      else
        style_bg = if bgcolor_default
                     "-fx-background-color:#{bgcolor_default};"
                   else
                     ""
                   end
        box.setStyle( style_bg + base_style)

        style_tx = "-fx-text-fill:#{color_default};" if color_default
      end
      
      if richtext.to_a.length > 0
        box.getChildren.clear()
        richtext.each{|h|
          if h[:e] == 'text'
            l = Label.new( h[:t] )
            l.setStyle( style_tx ) if style_tx
            box.getChildren.add( l )
          elsif h[:e] == 'emoji'
            iv = ImageView.new
            iv.setSmooth(true)
            iv.setFitHeight( @@emoji_height )
            iv.setPreserveRatio(true)
            i = @@cache[ h[:u] ]
            if not i
              i = if App.i.pref["image_reduction_with_image_object"]
                    Image.new( h[:u] , 0 , @@emoji_height , true,true,true)
                  else
                    Image.new( h[:u] , true )
                  end
              @@cache[ h[:u] ] = i
            end
            iv.setImage( i )
            box.getChildren.add( iv )
          end
        }
        box.setVisible(true)
      else
        if text and text.to_s.length > 0
          box.getChildren.clear()
          l = Label.new( text )
          l.setStyle( style_tx ) if style_tx
          box.getChildren.add( l )
          box.setVisible(true)
        else
          box.getChildren.clear()
          box.setVisible(false)
        end
      end
      box.applyCss # 事前に描画しちらつき防止?
    end
    
    def updateItem( data , is_empty_col )

      if( data and not is_empty_col )
        adjust

        time = Time.at( data[:created_utc] )
        @datetime.setText( time.strftime("%Y-%m-%d %H:%M:%S") )

        if @show_subreddit
          if data[:subreddit_type] == 'user'
            @subreddit.setText( "[ユーザー投稿]" )
          else
            @subreddit.setText( data[:subreddit] )
          end
        end

        set_richtext_to_box( @link_flair ,
                             data[:link_flair_richtext_decoded],
                             data[:link_flair_text_decoded],
                             data[:link_flair_text_color],
                             data[:link_flair_background_color],
                             App.i.theme::COLOR::REVERSE_TEXT, # default text
                             App.i.theme::COLOR::HTML_TEXT_THIN, # default bg
                             "-fx-border-color:#{App.i.theme::COLOR::HTML_COMMENT_BORDER}; -fx-border-width: 1 1 1 1;"
                             )
        
        if data[:over_18]
          @nsfw.setText(" NSFW ")
          @nsfw.setVisible(true)
        else
          @nsfw.setText("")
          @nsfw.setVisible(false)
        end

        if data[:spoiler]
          @spoiler.setText(" Spoiler ")
          @spoiler.setVisible(true)
        else
          @spoiler.setText("")
          @spoiler.setVisible(false)
        end

        if data[:stickied]
          @sticky.setText(" Announcement ")
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

        if data[:banned_by] == true
          @auto_banned.setText("スパムフィルタ")
          @auto_banned.setVisible(true)
        else
          @auto_banned.setText("")
          @auto_banned.setVisible(false)
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
        
        # p data[:author_flair_richtext_decoded]

        set_richtext_to_box( @user_flair ,
                             data[:author_flair_richtext_decoded],
                             data[:author_flair_text_decoded],
                             data[:author_flair_text_color],
                             data[:author_flair_background_color] ,
                             nil ,
                             nil ,
                             "-fx-border-color:#{App.i.theme::COLOR::HTML_COMMENT_BORDER}; -fx-border-width: 1 1 1 1;"
                             )
        
        if data[:gilded] == 1
          @gilded.setText("★")
        elsif data[:gilded].to_i > 1
          @gilded.setText("★" + data[:gilded].to_s )
        else
          @gilded.setText("")
        end
        gildings_silver = (data[:gildings] && data[:gildings][:gid_1]).to_i
        if gildings_silver == 1
          @gilded_s.setText("⚬")
        elsif gildings_silver > 1
          @gilded_s.setText("⚬" + gildings_silver.to_s )
        else
          @gilded_s.setText("")
        end
        gildings_platinum = (data[:gildings] && data[:gildings][:gid_3]).to_i
        if gildings_platinum == 1
          @gilded_p.setText("★")
        elsif gildings_platinum > 1
          @gilded_p.setText("★" + gildings_platinum.to_s )
        else
          @gilded_p.setText("")
        end
         
        if data[:view_count]
          if data[:view_count] == 1
            @views.setText("[1 view]")
          else
            @views.setText("[#{data[:view_count]} views]")
          end
        else
          @views.setText("")
        end

        @domain.setText( "(" + data[:domain].to_s + ")" )

        cps = if data[:crosspost_parent_list] and
                  data[:crosspost_parent_list].length > 0
                " ↜ " + data[:crosspost_parent_list][0][:subreddit].to_s
              else
                ""
              end
        @crosspost.setText( cps )
        
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
        url = Html_entity.decode(item[:url])
        
        page_info = @url_handler.url_to_page_info( url )
        if page_info[:type] == 'other'
          App.i.open_external_browser(url)
        else
          App.i.open_by_page_info( page_info )
        end
        
      end
    }
    
    # open_external_r = MenuItem.new("リンクを開く(readability)")
    # open_external_r.setOnAction{|e|
    #   if item = @table.getSelectionModel().getSelectedItem()
    #     url = Html_entity.decode(item[:url])
        
    #     page_info = @url_handler.url_to_page_info( url )
    #     if page_info[:type] == 'other'
    #       url_r = Util.mobile_url( url )
    #       App.i.open_external_browser(url_r)
    #     else
    #       App.i.open_by_page_info( page_info )
    #     end

    #   end
    # }

    open_comment_external = MenuItem.new("コメントを外部ブラウザで開く")
    open_comment_external.setOnAction{|e|
      if item = @table.getSelectionModel().getSelectedItem()
        url = item_to_comment_link( item )
        App.i.open_external_browser( url )
      end
    }

    menu = ContextMenu.new
    menu.getItems().addAll( open_external , open_comment_external )

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
      url = Html_entity.decode(item[:url])
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
    if is_table_bottoming_out
      key_add
    else
      @table.scrollTo( @table.getItems().size - 1 )
      select_row( @table.getItems().size - 1 )
    end
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
        # select_row( get_scroll_bottom ) # 下から出てくる
        select_row( get_scroll_top ) # 下から出てくる
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
        else
          # ロード動作
          key_add
        end
        
      else
        # select_row( get_scroll_top ) # 上から出てくる
        select_row( get_scroll_bottom ) # 上から出てくる
      end
    else
      if pos = get_scroll_top # 最初はトップ
        select_row( pos  ) 
      else
        key_add # 何もないとき追加ロード
      end
    end
  end

  #def key_space
  #  key_next
  #end

  def key_previous
    screen_scroll( false , true)
  end
  def key_next
    if is_table_bottoming_out
      key_add
    else
      screen_scroll( true , true)
    end
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
      url = Html_entity.decode(item[:url])
      page_info = @url_handler.url_to_page_info( url )
      if page_info[:type] == 'other'
        App.i.open_external_browser(url)
      else
        App.i.open_by_page_info( page_info )
      end
    end
  end
  
  # def key_open_link_alt
  #  if item = @table.getSelectionModel().getSelectedItem()
  #    url = Html_entity.decode(item[:url])
  #    App.i.open_external_browser(Util.mobile_url(url))
  #  end
  # end
  
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

  def key_no_thumb
    @no_thumb_button.fire
  end
  
  def key_small_thumb
    @small_thumb_button.fire
  end

  def key_medium_thumb
    @medium_thumb_button.fire
  end

  def key_thumb
    kw = App.i.key_stroke_command_window
    kw.add_choice("n","なし") do
      @no_thumb_button.fire
    end
    kw.add_choice("s","小") do
      @small_thumb_button.fire
    end
    kw.add_choice("m","中") do
      @medium_thumb_button.fire
    end
    kw.start( "サムネイル設定" )
  end

  def key_filter
    kw = App.i.key_stroke_command_window
    kw.add_choice("u","upvoteしたもの") do
      @filter_upvoted.fire if not @filter_upvoted.isDisable
    end
    kw.add_choice("n","既読スレで新着があるもの") do
      @filter_read.fire if not @filter_read.isDisable
    end
    kw.add_choice("c","全フィルタ解除") do
      @on_clearing = true
      @filter_upvoted.setSelected(false)
      @filter_read.setSelected(false)
      @filter_text.setText("")
      display_subms
      @on_clearing = false
    end
    kw.add_choice("/","検索語欄に移動" ) do
      key_find
    end
    kw.start("フィルタ選択")
  end

  def key_web
    url = get_sub_url
    if url.to_s.length > 0
      App.i.open_external_browser( url.to_s )
    end
  end

end
