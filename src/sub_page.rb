# -*- coding: utf-8 -*-

require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'pref/subs'
require 'pref/account'
require 'app'
require 'util'

require 'page'
require 'account_selector'

require 'url_handler'
require 'html/html_entity'

require 'app_color'

require 'glyph_awesome'

import 'javafx.scene.control.cell.MapValueFactory'
# import 'javafx.beans.property.SimpleStringProperty'
import 'javafx.beans.property.SimpleMapProperty'
import 'javafx.beans.property.SimpleObjectProperty'
import 'javafx.scene.control.cell.TextFieldTableCell'
import 'javafx.scene.text.TextFlow'
import 'javafx.application.Platform'

class SubPage < Page
  
  def initialize( info )
    super(3.0)
    getStyleClass().add("sub-page")
    
    @page_info = info
    @page_info[:site] ||= 'reddit'
    @page_info[:type] ||= 'sub'
    
    @artificial_bold = App.i.pref["artificial_bold"]

    @url_handler = UrlHandler.new( @page_info[:site] )
    $stderr.puts "sub_page @page_info[:name] = #{@page_info[:name]}"
    
    @pref = Subs.new( @page_info[:name] , site:@page_info[:site] )
    setSpacing(3.0)
    @thread_pool = []
    if not Account.exist?( @pref['account_name'] )
      @pref['account_name'] = nil
    end
    if not Account.exist?( @page_info[:account_name] )
      @page_info[:account_name] = nil
    end
    @account_name = @pref['account_name'] || @page_info[:account_name] || App.i.pref['current_account'] # ページごとの記録が優先
    @pref['account_name'] = @account_name
    @sub_info = nil

    @is_multireddit = @url_handler.path_is_multireddit( @page_info[:name] )

    ### ボタン第一列
    # @toolbar = ToolBar.new() # ツールバーは良くない はじっこが切れるからだっけ
    @button_area = BorderPane.new
    @button_area_right = HBox.new(3.0)
    @button_area_right.setAlignment( Pos::CENTER_LEFT )
    @account_selector = AccountSelector.new( @account_name )
    # @account_selector.valueProperty().addListener{|ev|
    @account_selector.set_change_cb{ # アカウントリロード時には呼ばない
      # $stderr.puts ev.getValue()
      value = @account_selector.getValue()

      if not @account_loading
        if @account_name != @account_selector.get_account
          @account_name = @account_selector.get_account # 未ログイン = nil
          @pref['account_name'] = @account_name
          start_reload
        end
      end
    }

    @title_label = Label.new( subpath_to_name(@page_info[:name]) )
    @title_label.setStyle("-fx-font-size:16pt")

    @active_label = Label.new()

    @external_browser_button = Button.new("webで開く")
    @external_browser_button.setOnAction{|e|
      url = get_sub_url
      if url.to_s.length > 0
        App.i.open_external_browser( url.to_s )
      end
      
    }

    @button_area.setLeft( @account_selector )
    BorderPane.setAlignment( @title_label , Pos::CENTER_LEFT )
    @button_area.setCenter( @title_label )

    @button_area_right.getChildren().addAll( Separator.new( Orientation::VERTICAL ),
                                             @active_label ,
                                             @external_browser_button)
    
    if not @is_multireddit
      @external_post_page_button = Button.new("投稿ページ")
      @external_post_page_button.setOnAction{|e|
        url = get_sub_url
        if url.to_s.length > 0
          App.i.open_external_browser( url.to_s + "submit" )
        end
      }
      @button_area_right.getChildren().add( @external_post_page_button )
    end

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
    @sort_buttons << @sort_hot = ToggleButton.new("注目")
    @sort_buttons << @sort_new = ToggleButton.new("新着")
    @sort_buttons << @sort_contr_day = ToggleButton.new("物議(日)")
    @sort_buttons << @sort_contr_week = ToggleButton.new("物議(週)")
    # 票数,コメント

    @sort_button_group = ToggleGroup.new()
    @sort_buttons.each{|b| b.setToggleGroup( @sort_button_group) }

    App.i.make_pill_buttons( @sort_buttons )

    # old_sort = @sort_hot # todo:prefからやること
    # @sort_button_group.selectToggle( old_sort )
    # @sort_button_group.selectedToggleProperty().addListener{|obj|
    #   new_selected = obj.getValue()
    #   if new_selected
    #     if old_sort != new_selected
    #       old_sort = new_selected
    #       start_reload
    #     end
    #   else
    #     # 必ずどれかが選択された状態に
    #     @sort_button_group.selectToggle( old_sort )
    #   end
    # }
 
    Util.toggle_group_set_listener_force_selected( @sort_button_group ,
                                                   @sort_hot){|btn| start_reload }
    
    @sort_button_area_left.getChildren().add( Label.new("ソート:"))
    @sort_button_area_left.getChildren().addAll( @sort_buttons )
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
        elsif ev.getText.to_s.length > 0 and ev.getText.ord >= 32
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
      SimpleObjectProperty.new( [ cdf.getValue() , @account_name ] )

    }
    vote_column.set_cell_factory{|col| VoteCell.new() }
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
              open_selected_submission()
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
        open_selected_submission()
      end
    }
    
    getChildren().add( @table )

    # 本体
    self.class.setMargin( @button_area , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @sort_button_area , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @filter_and_search_bar , Insets.new(3.0 , 3.0 , 0 , 3.0) ) # trbl
    self.class.setMargin( @table , Insets.new(3.0, 3.0 , 0 , 3.0) )
    
    # tab
    prepare_tab( make_tab_name , "/res/list.png")

    @tab.setOnClosed{
      finish()
    }

    # subのデータ取得
    if @is_multireddit
      @active_label.setText("[multi]")
    else
      start_load_sub_info
    end
    start_reload
  end # initialize
  
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
    name = if @sub_info
             @sub_info[:display_name]
           else
             subpath_to_name(@page_info[:name])
           end

    owner = if @is_multireddit.is_a?(String)
              " [" + @is_multireddit + "]"
            else
              ""
            end
    name + owner
  end

  def start_load_sub_info
    @load_sub_info_thread = Thread.new{
      loop do

        begin
          @sub_info = App.i.client(@account_name).subreddit_from_name( @page_info[:name] )
          if @sub_info
            title = @sub_info[:title] || subpath_to_name(@page_info[:name])
            Platform.runLater{
              @title_label.setText( Html_entity.decode(title) )
              set_tab_text( make_tab_name )
              @active_label.setText("ユーザー数: #{@sub_info[:accounts_active].to_i}/#{@sub_info[:subscribers]}")
            }
          end
        rescue
          $stderr.puts "sub情報取得失敗"
        end
      
        sleep( 300 + rand( 10 ) )
      end # loop
    }
  end

  def finish
    if @load_sub_info_thread
      begin
        @load_sub_info_thread.kill
      rescue
        
      end
      @load_sub_info_thread = nil
    end
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

  def reload( add:false , count:100)
    $stderr.puts "reload"
    set_load_button_enable( false )
    cl = App.i.client(@account_name)
    $stderr.puts cl.access.to_json ########

    after = if add and @subms.to_a.length > 0
              @subms.last[:name]
            else
              @subms = []
              nil
            end
    
    begin
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
          
          obj[:reddo_thumbnail_decoded] = if obj[:thumbnail] =~ /^http/o
                                            Html_entity.decode( obj[:thumbnail] )
                                          else
                                            url , w , h = Util.find_submission_preview(obj)
                                            if url
                                              Html_entity.decode( url )
                                            else
                                              nil
                                            end
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
      # 相対パスである
      @url_handler.linkpath_to_url(@sub_info[:url])
    else
      @url_handler.subname_to_url( @page_info[:name] )
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
      set_scroll_amount
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

  def get_scroll_top
    if vf = get_virtual_flow
      cell = vf.getFirstVisibleCellWithinViewPort() || vf.getFirstVisibleCell()
      if cell
        cell.getIndex()
      else
        nil
      end
    else
      nil
    end
  end

  def selection_is_in_view
    sel = @table.getSelectionModel.getSelectedIndex()
    (st = get_scroll_top) and (st <= sel ) and (ed = get_scroll_bottom) and (sel <= ed)
  end

  def get_scroll_bottom
    if vf = get_virtual_flow
      cell = vf.getLastVisibleCellWithinViewPort() || vf.getLastVisibleCell()
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
      amount = ((last - first) * ratio).to_i
      amount = 1 if amount < 1

      amount = if forward
                 amount
               else
                 amount * -1
               end

      $stderr.puts "screen_scroll #{first} + #{amount}"

      target = first + amount

      @table.scrollTo( target )
      target
    end
  end

  def set_scroll_amount
    if vf = get_virtual_flow
      vf.setOnScroll{|ev|
        screen_scroll( ev.getDeltaY() < 0 , 0.6) # -1なら↓
        ev.consume
      }
    end
  end

  def filter(subms_in)
    word = @filter_text.getText().downcase
    filter_upvoted = @filter_upvoted.isSelected()

    subms = subms_in
    if( word.length > 0 )
      subms = subms.find_all{|subm|
        subm[:title_decoded].to_s.downcase.index( word ) or
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
    start_buttons = [ @reload_button , @account_selector , @subm_add_button ] + @sort_buttons
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

  def open_selected_submission
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
                               :account_name => comm_account })
    
  end

  class VoteCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl
    STYLE_BASE = "-fx-font-size:12px;"
    def initialize()
      super()
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
          @upvote_button.setStyle("#{STYLE_BASE} -fx-text-fill:orange")
        else
          @upvote_button.setStyle(STYLE_BASE)
        end
        if @downvote_button.isSelected
          vote_score = -1
          @downvote_button.setStyle("#{STYLE_BASE} -fx-text-fill:blue")
        else
          @downvote_button.setStyle(STYLE_BASE)
        end
        
        it = getTableRow().getItem
        if it and it[:reddo_vote_score] != vote_score
          getTableView().getItems().subList( index , index + 1).replaceAll{|item| 
            item[:reddo_score] = item[:score] - item[:reddo_orig_vote_score] + vote_score
            item[:reddo_vote_score] = vote_score

            # p item.client.

            Thread.new{
              $stderr.puts "vote thread start"
              begin
                c = App.i.client( @account_name ) # token更新のため
                # $stderr.puts "リフレッシュ"
                case vote_score
                when 1
                  item.upvote
                when -1
                  item.downvote
                when 0
                  item.clear_vote
                end
                App.i.mes("投票しました #{item[:name]}")
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
    
    def updateItem( data_ac , is_empty_col )
      data , @account_name = data_ac
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

        if @account_name
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
      @number.setStyle( "-fx-font-size:20px")
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
      @number.setStyle( "-fx-font-size:20px")
      setAlignment( Pos::CENTER_RIGHT )
      setGraphic(@number)
    end

    def updateItem( data , is_empty_col )
      if data and not is_empty_col
        case data[:reddo_vote_score]
        when 1
          @number.setStyle( "-fx-font-size:20px;-fx-text-fill:orange")
        when -1
          @number.setStyle( "-fx-font-size:20px;-fx-text-fill:blue")
        else
          @number.setStyle( "-fx-font-size:20px;")
        end
        
        @number.setText(data[:reddo_score].to_s )
      else
        @number.setText("")
      end
    end
  end

  class TitleCell < Java::JavafxSceneControl::TableCell
    include JRubyFX::DSLControl

    # FONT_FAMILY = '-fx-font-family:"Meiryo";' # 暫定
    @@dummy_label = nil
    @@dummy_scene = nil

    def initialize(col = nil , artificial_bold:false, show_subreddit:false)
      super()
      @show_subreddit = show_subreddit

      # @subm_title = Label.new
      @subm_title = Text.new
      # @subm_title.setWrapText(true)
      if artificial_bold
        # drowshadow ( blur-type , color , radius , spread, offset_x , offset_y )
        @subm_title.setStyle( "-fx-font-size:14px; -fx-word-wrap:break-word; -fx-effect: dropshadow( one-pass-box , black , 0,0,1,0 );")
      else
        @subm_title.setStyle( "-fx-font-size:14px; -fx-font-weight: bold; -fx-word-wrap:break-word")
      end

      if @show_subreddit
        @subreddit = Label.new
        @subreddit.setStyle( "-fx-text-fill:green;-fx-padding:0 6px 0 0;")
        @subreddit.setWrapText(false)
      end

      @nsfw = Label.new("NSFW")
      @nsfw.setStyle("-fx-text-fill:white; -fx-background-color:#{AppColor::DARK_RED}")
      @nsfw.setWrapText(false)

      @link_flair = Label.new
      @link_flair.setStyle( "-fx-text-fill:#dddddd; -fx-background-color:#222222;")
      @link_flair.setWrapText(false)

      @datetime = Label.new
      @datetime.setStyle( "-fx-padding:0 6px 0 0;")
      @datetime.setWrapText(false)

      @sticky = Label.new("Sticky")
      @sticky.setStyle("-fx-text-fill:white; -fx-background-color:#{AppColor::DARK_GREEN}")
      @sticky.setWrapText(false)

      @author = Label.new
      @author.setStyle("-fx-text-fill:#{AppColor::DARK_BLUE};")
      @author.setWrapText(false)
      
      @user_flair = Label.new
      @user_flair.setStyle( "-fx-border-color:black; -fx-border-width: 1 1 1 1" )
      @user_flair.setMaxWidth( 200 )
      @user_flair.setWrapText(false)

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

      @hbox2 = HBox.new()
      @hbox2.setAlignment( Pos::CENTER_LEFT )
      @hbox2.getChildren().add( @subreddit ) if @show_subreddit
      @hbox2.getChildren().add( @nsfw )
      @hbox2.getChildren().add( @sticky )
      @hbox2.getChildren().add( @link_flair )
      @hbox2.getChildren().add( @domain )

      @box = VBox.new
      @box.setAlignment( Pos::TOP_LEFT )
      @box.getChildren().add( @hbox )
      @box.getChildren().add( @hbox2 )
      @box.getChildren().add( @subm_title )

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

        author = data[:author].to_s
        if d = data[:distinguished]
          author += "[" + d[0].to_s + "]"
          if d == 'moderator'
            @author.setStyle("-fx-text-fill:#{AppColor::DARK_GREEN};")
          elsif d == 'admin'
            @author.setStyle("-fx-text-fill:#{AppColor::DARK_RED};")
          else
            @author.setStyle("-fx-text-fill:#{AppColor::DARK_BLUE};")
          end
        else
          @author.setStyle("-fx-text-fill:#{AppColor::DARK_BLUE};")
        end
        @author.setText( author )

        if afl = data[:author_flair_text] and afl.to_s.length > 0
          @user_flair.setText( afl )
          @user_flair.setVisible(true)
        else
          @user_flair.setText( "" )
          @user_flair.setVisible(false)
        end
        
        @domain.setText( "(" + data[:domain].to_s + ")" )

        @subm_title.setText( data[:title_decoded].to_s.strip  )
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
        if item = @table.getSelectionModel().getSelectedItem()
          subname = item[:subreddit]
          page_info = { 
            type:"sub" , 
            site:@page_info[:site] , 
            name:subname ,
            account_name: @account_name
          }
          App.i.open_by_page_info( page_info )
        end
      }
      
      menu.getItems().add( open_sub )
    end

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
    }

    menu
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
    if index >= 0
      if index > 0
        $stderr.puts "set selection"
        select_row( index - 1 )
        if not selection_is_in_view
          @table.scrollTo( index - 1)
        end
      end
    else
      select_row( get_scroll_top )
    end
  end
  
  def key_down
    index = @table.getSelectionModel().getSelectedIndex()
    if index >= 0
      if index < @table.getItems().size - 1
        select_row( index + 1 )
        if not selection_is_in_view
          @table.scrollTo( index + 1 - (get_scroll_bottom - get_scroll_top) )
        end
      end
    else
      select_row( get_scroll_top )
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
  
  def key_add
    @subm_add_button.fire() if not @subm_add_button.isDisable()
  end

  def key_hot
    @sort_hot.fire() if not @sort_hot.isDisable()
  end

  def key_new
    @sort_new.fire() if not @sort_new.isDisable()
  end

  def key_upvote()
    item = @table.getSelectionModel().getSelectedItem()
    if item
      name = item[:name]
      btn = @table.lookupAll(".upvote-button").find{|btn| btn.getUserData() == item[:name] }
      btn.fire() if btn and not btn.isDisable()
    end
  end

  def key_downvote
    item = @table.getSelectionModel().getSelectedItem()
    if item
      name = item[:name]
      btn = @table.lookupAll(".downvote-button").find{|btn| btn.getUserData() == item[:name] }
      btn.fire() if btn and not btn.isDisable()
    end
  end

  def key_find
    @filter_text.requestFocus()
    @filter_text.selectRange( 0 , @filter_text.getText().length  )
  end

end
