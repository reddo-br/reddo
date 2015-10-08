# -*- coding: utf-8 -*-

# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'page'

import 'javafx.scene.control.Spinner'

class ConfigPage < Page

  def initialize(info)
    super()
    @page_info = info
    scroll_pane = ScrollPane.new()
    scroll_pane.setPrefHeight( 2000 )
    grid_pane = GridPane.new()

    scroll_pane.setContent( grid_pane )

    items = []

    @font_selector = ChoiceBox.new
    font_list = ["未設定"] + Font.getFamilies()
    @font_selector.getItems().setAll( font_list )
    @font_selector.getSelectionModel.select( get_font )
    @font_selector.valueProperty.addListener{|ev|
      set_font( ev.getValue )
    }
    items << [ Label.new("フォント") , @font_selector ]

    items << make_bool_config( "太字フォントをcss shadowで再現する(太字が表示できない場合に試してください)" ,
                               "artificial_bold" )

    items << make_bool_config( "外部ブラウザを開く別の方法を試す(うまくいかない場合に)" ,
                               "browse_alternative_method" )

    items << make_bool_config( "新規タブを現在のタブの直後に挿入する",
                               "new_tab_after_current" )

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
    
    ########## itemをgridpaneに入れる

    items.each_with_index{|row , rownum|
      row.each_with_index{|control , colnum|
        GridPane.setColumnIndex( control , colnum )
        GridPane.setRowIndex( control , rownum )
        
        if colnum == 0
          #labels
          control.setWrapText(true)
          control.setStyle("-fx-word-wrap:break-word")
        end

        GridPane.setMargin( control , Insets.new( 5 , 5 , 5 , 5))
        grid_pane.getChildren().add( control )
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
    label_top.setStyle("-fx-font-size:16px")
    getChildren.add( label_top )
    getChildren.add( scroll_pane )

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

end
