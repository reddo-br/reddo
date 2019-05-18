# -*- coding: utf-8 -*-

# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'page'
require 'comment_page'

require 'util'

import 'javafx.scene.control.Spinner'

class ConfigPage < Page

  SUB_SCROLL_AMOUNT_CHOICES = [[ nil , "ui標準" ],
                               [ 0.001 , "一行" ],
                               [ 0.25 , "画面の約25%" ],
                               [ 0.5 ,  "画面の約50%" ],
                               [ 1.0 ,  "約1画面分"   ]]
  
  def initialize(info)
    super()
    setSpacing(3.0)
    setStyle("-fx-border-width:1px; -fx-border-style:solid; -fx-border-color:#{App.i.theme::COLOR::PAGE_BORDER};")
    @page_info = info
    scroll_pane = ScrollPane.new()
    scroll_pane.setPrefHeight( 2000 )
    grid_pane = GridPane.new()

    scroll_pane.setContent( grid_pane )

    items = []

    items << make_header( "全般" )

    items << make_bool_config( "新規タブを現在のタブの直後に挿入する",
                               "new_tab_after_current" )

    items << make_bool_config( "ダークテーマ(試験的)" , 
                               "use_dark_theme" )

    items << make_bool_config( "透過ウインドウの使用を避ける(一部のウィンドウに白い枠が出る場合などに)" , 
                               "dont_use_transparent_window" )
    
    items << make_bool_config( "新規タブを開いたときにフォーカスしない" ,
                               "dont_focus_on_new_tab" )

    items << make_header( "フォント")

    @font_selector = ChoiceBox.new
    font_list = ["未設定"] + Font.getFamilies()
    @font_selector.getItems().setAll( font_list )
    @font_selector.getSelectionModel.select( get_font )
    @font_selector.valueProperty.addListener{|ev|
      set_font( ev.getValue )
      set_font_sample
    }
    items << [ Label.new("フォント選択") , @font_selector ]

    # items << make_bool_config( "太字フォントをcss shadowで再現する(太字が表示できない場合に試してください)" ,
    # "artificial_bold" )

    @artificial_bold_check = CheckBox.new
    @artificial_bold_check.setSelected( App.i.pref[ 'artificial_bold' ] )
    @artificial_bold_check.selectedProperty.addListener{|ov|
      App.i.pref[ 'artificial_bold' ] = ov.getValue
      set_font_sample
    }

    items << [ Label.new("太字フォントをcss shadowで再現する(太字が表示できないフォントで試してください)" ),
               @artificial_bold_check ]

    @artificial_oblique_check = CheckBox.new
    @artificial_oblique_check.setSelected( App.i.pref[ 'artificial_oblique' ] )
    @artificial_oblique_check.selectedProperty.addListener{|ov|
      App.i.pref[ 'artificial_oblique' ] = ov.getValue
      set_font_sample
    }

    items << [ Label.new("斜体フォントを人工的に表示する(同じく)" ),
               @artificial_oblique_check ]

    items << [ Label.new("") , make_font_sample ]

    items << make_bool_config( "サブピクセルレンダリングではなく、グレースケール・アンチエイリアシングを使用する(環境によっては、変化ありません)",
                               "grayscale_antialiasing" )

    ####################################
    items << make_header("画像")

    items << make_bool_config( "アイコン等の画質を改善(高DPI環境では、ぼけます)",
                               "image_reduction_with_image_object")
    
    ####################################
    items << make_header("外部ブラウザ")
    
    items << make_bool_config( "外部ブラウザを開く別の方法を試す(うまくいかない場合に)" ,
                               "browse_alternative_method" )

    ol ,oc = make_bool_config( "外部ブラウザをコマンドで指定" ,
                               "specify_browser_in_command" )
    items << [ol,oc]

    shell_command_field = TextField.new("")
    shell_command_field.setDisable( (not oc.selected) )
    # shell_command_field.setPromptText("例: firefox -new-tab \"%u\"")
    shell_command_field.setText( App.i.pref["browser_command" ] )

    items << [ Label.new("ブラウザのコマンド"),
               shell_command_field ]
    oc.selectedProperty.addListener{|ev|
      val = ev.getValue
      if val
        shell_command_field.setDisable(false)
      else
        shell_command_field.setDisable(true)
      end
    }
    shell_command_field.textProperty.addListener{|ev|
      App.i.pref[ "browser_command" ] = ev.getValue
    }
    #####################################

    items << make_header("サブレディット画面")

    items << make_spinner_config( "一度に取得する投稿数(20〜100)",
                                  "sub_number_of_posts_to_get",
                                  20 , 100 , 100 , 10 )
    
    ######################################
    items << make_header( "コメント画面" )

    items << make_bool_config( "コメントページを開いた時に自動更新を有効にする",
                               'enable_autoreload' )
    
    items << make_bool_config( "コメント内のリンクの下線を常時表示する" ,
                               "underline_link")

    items << make_bool_config( "連続するunicode結合文字を省略する(コメントにより描画に非常に時間がかかる問題を回避する)" ,
                               "suppress_combining_mark")

    # line height
    # line_height = App.i.pref['line_height'] || 100
    # @line_height_spinner = Spinner.new( 100 , 200 , line_height , 5 )
    # @line_height_spinner.getValueFactory.valueProperty.addListener{|ev|
    #   App.i.pref['line_height'] = ev.getValue
    # }
    # items << [ Label.new("行間(%)") , @line_height_spinner ]
    
    items << make_spinner_config( "行間(%)" ,
                                  "line_height",
                                  100, 250 , 140 , 5 )
    
    items << make_spinner_config( "開始時の文字の大きさ(%)",
                                  "comment_page_font_zoom",
                                  50 , 300 , 100 , 10)
    
    sort_choices = CommentPage::SORT_TYPES.map{|name,value| [value,name] } # 逆になってる
    items << make_choices_config( "コメントのデフォルトソート(サブレディットからの提案がない場合)",
                                  "default_comment_sort","new",
                                  sort_choices )

    items << make_bool_config( "トップコメントの枠の間隔を詰める" ,
                               "collapse_comment_margin" )

    items << make_header( "スクロール関係" )

    scrv2_lbl , scrv2_w = 
      make_bool_config( "マウスホイールでのスクロール動作をカスタマイズする" ,
                        "scroll_v2_enable")
    items << [scrv2_lbl , scrv2_w]

    scrv2_wa_lbl , scrv2_wa_w = 
      make_spinner_config( "マウスホイールでの移動量(50px - 300px)",
                           "scroll_v2_wheel_amount",
                           50 , 300 , 100 , 10 )
    items << [scrv2_wa_lbl , scrv2_wa_w]

    scrv2_accel_lbl , scrv2_accel_w = 
      make_spinner_config( "マウスホイールスクロールの最大加速倍率(1x - 10x)",
                           "scroll_v2_wheel_accel_max",
                           1.0 , 10.0 , 2.5 , 0.5 )
    items << [ scrv2_accel_lbl , scrv2_accel_w]

    scrv2_smooth_lbl , scrv2_smooth_w =  
      make_bool_config( "スムーズスクロールを使用する(実験中)" ,
                        "scroll_v2_smooth")
    items << [ scrv2_smooth_lbl , scrv2_smooth_w ]

    # ウィジェット無効化
    scrv2_config_widgets = [ scrv2_wa_w , scrv2_accel_w ]
    scrv2_config_widgets.each{|w| w.setDisable( (not scrv2_w.isSelected) ) }
    scrv2_w.selectedProperty.addListener{|ev|
        scrv2_config_widgets.each{|w| w.setDisable( (not ev.getValue) ) }
    }

    items << make_header("情報")
    
    items << [ Label.new("ユーザーディレクトリ" ) , 
               Label.new( Util.get_appdata_pathname.to_s ) ]

    ########## itemをgridpaneに入れる

    items.each_with_index{|row , rownum|
      row.each_with_index{|control , colnum|
        if control
          GridPane.setColumnIndex( control , colnum )
          GridPane.setRowIndex( control , rownum )
          
          if colnum == 0
            #labels
            control.setWrapText(true)
            control.setStyle(control.getStyle + "; -fx-word-wrap:break-word")
          end
          
          GridPane.setMargin( control , Insets.new( 5 , 5 , 5 , 5))
          grid_pane.getChildren().add( control )
        end
      }
    }

    column_1 = ColumnConstraints.new(350)
    column_2 = ColumnConstraints.new(350)
    #column_1.setPercentWidth( 50 )
    #column_2.setPercentWidth( 50 )
    column_1.setHalignment( HPos::LEFT )
    column_2.setHalignment( HPos::LEFT  )
    grid_pane.getColumnConstraints().addAll(column_1, column_2)

    label_top = Label.new("設定の反映にはだいたい再起動が必要です")
    label_top.setStyle("-fx-font-size:130%")
    getChildren.add( label_top )
    getChildren.add( scroll_pane )
    self.class.setMargin( label_top , Insets.new(3.0 , 3.0 , 3.0 , 3.0) )
    self.class.setMargin( scroll_pane , Insets.new(3.0 , 3.0 , 3.0 , 3.0) )

    prepare_tab( "設定" )

    if App.i.pref["scroll_v2_enable"]
      scroll_setting(grid_pane,scroll_pane)
    end
    grid_pane.requestFocus
  end

  def checkbox_with_pref( pref_name )
    check = CheckBox.new
    check.setSelected( App.i.pref[ pref_name ] )
    check.selectedProperty().addListener{|ev|
      App.i.pref[ pref_name ] = ev.getValue()
    }
    check
  end
  
  def make_bool_config( label_string , pref_name )
    label = Label.new( label_string )
    check = checkbox_with_pref( pref_name )
    [ label , check ]
  end
  
  def make_choices_config( label_string , pref_name , default_value , val_name_array )
    current_val = App.i.pref[ pref_name ] || default_value
    selector = ChoiceBox.new
    selector.getItems.setAll( val_name_array.map{|e| e[1] } )
    selector.getSelectionModel.select( val_name_array.assoc( current_val )[1] )
    selector.valueProperty.addListener{|ev|
      val = val_name_array.rassoc( ev.getValue )[0]
      App.i.pref[ pref_name ] = val
    }
    
    [ Label.new( label_string ) ,  selector ]
  end

  def make_spinner_config( label_string , pref_name , min , max , default , step )
    current_val = App.i.pref[ pref_name ] || default
    spinner = Spinner.new( min , max , current_val , step )
    spinner.getValueFactory.valueProperty.addListener{|ev|
      App.i.pref[ pref_name ] = ev.getValue
    }

    [ Label.new( label_string ) , spinner ]
  end

  def make_header( label_string )
    label = Label.new( label_string )
    style = "-fx-padding:1em 0 0 0;-fx-underline:true;#{App.i.fx_bold_style("-fx-text-base-color")}"
    
    label.setStyle( style )
    [ label , nil ]
  end

  def get_font
    font = App.i.pref["fonts"]
    if font
      font
    else
      "未設定"
    end
  end

  def set_font(font)
    if font == "未設定"
      App.i.pref["fonts"] = nil
    else
      App.i.pref["fonts"] = font
    end
  end

  def make_font_sample
    h = VBox.new
    @font_sample_1 = Label.new("フォントサンプル abc 012")
    @font_sample_2 = Label.new("太字サンプル abc 012")
    @font_sample_3 = Label.new("斜体サンプル abc 012")

    @trans_oblique = Shear.new( Math.sin( Math::PI * (-15 / 180.0)) , 0 , 0 , 8) # 右20度傾け

    set_font_sample
    h.getChildren.addAll( @font_sample_1 , 
                          @font_sample_2,
                          @font_sample_3
                          )
    h
  end

  def set_font_sample
    $stderr.puts "set_font_sample"
    family = App.i.pref["fonts"]
    family_css = if family
                   "-fx-font-family:\"#{family}\";"
                 else
                   ""
                 end

    bold_css = App.i.fx_bold_style( '-fx-text-base-color' )
    @font_sample_1.setStyle("#{family_css}")
    @font_sample_2.setStyle("#{family_css} #{bold_css}")

    if App.i.pref["artificial_oblique"]
      @font_sample_3.setStyle("#{family_css}")
      if not @font_sample_3.getTransforms.contains( @trans_oblique )
        @font_sample_3.getTransforms.add( @trans_oblique )
      end
    else
      @font_sample_3.setStyle("#{family_css}; -fx-font-style:oblique;")
      @font_sample_3.getTransforms.clear
    end
  end

  def scroll_setting(w,scroll_pane)
    # 新ホイールスクロール機構の設定
    @wheel_base_amount = App.i.pref["scroll_v2_wheel_amount"] || 100
    @wheel_accel_max   = App.i.pref["scroll_v2_wheel_accel_max"] || 2.5

    # w = scroll_pane.lookupAll(".scroll-bar").to_a[0]

    w.setOnScroll{|ev|
      if ev.eventType == ScrollEvent::SCROLL
        puts "config_page scroll"
        scroll_pane_scroll( scroll_pane , ev )
      end
      ev.consume
    }
  end
  def scroll_pane_scroll(scroll_pane , ev)
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

    amount_pix = @wheel_base_amount * accel * dir
    amount_ratio = amount_pix / scroll_pane.getContent.getHeight().to_f
    amount_vval  = scroll_pane.getVmax * amount_ratio
    puts "amount_pix=#{amount_pix} amount_ratio=#{amount_ratio} amount_vval = #{amount_vval}"
    scroll_pane.setVvalue( scroll_pane.getVvalue + amount_vval)
    @last_scroll_time_msec = mt
  end

end
