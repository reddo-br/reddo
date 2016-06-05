# -*- coding: utf-8 -*-

# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'page'

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

    @font_selector = ChoiceBox.new
    font_list = ["未設定"] + Font.getFamilies()
    @font_selector.getItems().setAll( font_list )
    @font_selector.getSelectionModel.select( get_font )
    @font_selector.valueProperty.addListener{|ev|
      set_font( ev.getValue )
      set_font_sample
    }
    items << [ Label.new("フォント") , @font_selector ]

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

    items << [ Label.new("") , make_font_sample ]

    items << make_bool_config( "新規タブを現在のタブの直後に挿入する",
                               "new_tab_after_current" )

    items << make_bool_config( "ダークテーマ(試験的)" , 
                               "use_dark_theme" )

    items << make_bool_config( "透過ウインドウの使用を避ける(一部のウィンドウに白い枠が出る場合などに)" , 
                               "dont_use_transparent_window" )
    
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

    # スクロール量
    sub_scroll_amount = App.i.pref["sub_scroll_amount"]
    @sub_scroll_amount_selector = ChoiceBox.new
    @sub_scroll_amount_selector.getItems().setAll( SUB_SCROLL_AMOUNT_CHOICES.map{|e| e[1] })
    @sub_scroll_amount_selector.getSelectionModel.select( SUB_SCROLL_AMOUNT_CHOICES.assoc(sub_scroll_amount)[1] )
    @sub_scroll_amount_selector.valueProperty.addListener{|ev|
      am = SUB_SCROLL_AMOUNT_CHOICES.rassoc( ev.getValue )[0]
      App.i.pref['sub_scroll_amount'] = am
    }

    items << [ Label.new("サブレディット画面でのホイールスクロール量") , @sub_scroll_amount_selector ]

    items << make_header( "コメント画面" )

    items << make_bool_config( "サブレディットのリンク(スタンプ)とフレアーのスタイルを適用する(試験的)",
                               'use_sub_link_style')

    items << make_bool_config( "コメントページを開いた時に自動更新を有効にする",
                               'enable_autoreload' )
    
    items << make_bool_config( "コメントページでスムーズスクロールを使用する" ,
                               "enable_smooth_scroll")

    accel = App.i.pref['wheel_accel_max'] || 2.5
    @accel_spinner = Spinner.new( 1.0 , 5.0 , accel , 0.5 )
    @accel_spinner.getValueFactory.valueProperty.addListener{|ev|
      App.i.pref['wheel_accel_max'] = ev.getValue
    }
    items << [ Label.new("コメントページでのマウスホイールスクロールの最大加速"),
               @accel_spinner ]
    
    items << make_bool_config( "連続するunicode結合文字を省略する(コメントにより描画に非常に時間がかかる問題を回避する)" ,
                               "suppress_combining_mark")

    # line height
    line_height = App.i.pref['line_height'] || 100
    @line_height_spinner = Spinner.new( 100 , 200 , line_height , 5 )
    @line_height_spinner.getValueFactory.valueProperty.addListener{|ev|
      App.i.pref['line_height'] = ev.getValue
    }
    items << [ Label.new("行間(%)") , @line_height_spinner ]
    
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

  def make_header( label_string )
    label = Label.new( label_string )
    style = "-fx-padding:1em 0 0 0;-fx-underline:true;"
    style += if App.i.pref["artificial_bold"]
      "-fx-effect: dropshadow( one-pass-box , -fx-text-base-color , 0,0,1,0 );"
    else
      "-fx-font-weight:bold;"
    end
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
    h = HBox.new
    @font_sample_1 = Label.new("フォントサンプル abc 012")
    @font_sample_2 = Label.new("太字サンプル abc 012")
    set_font_sample
    h.getChildren.addAll( @font_sample_1 , 
                       Label.new(" "),
                       @font_sample_2 )
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
    bold_css = if App.i.pref["artificial_bold"]
                 "-fx-effect: dropshadow( one-pass-box , -fx-text-base-color , 0,0,1,0 );"
               else
                 "-fx-font-weight:bold;"
               end
    p "#{family_css} #{bold_css}"
    @font_sample_1.setStyle("#{family_css}")
    @font_sample_2.setStyle("#{family_css} #{bold_css}")

  end
end
