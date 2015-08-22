# -*- coding: utf-8 -*-

# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'page'

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

    @bold_check = CheckBox.new
    @bold_check.setSelected( App.i.pref["artificial_bold"] )
    @bold_check.selectedProperty().addListener{|ev|
      App.i.pref["artificial_bold"] = ev.getValue()
    }

    bold_label = Label.new("太字フォントをcss shadowで再現する(太字が表示できない場合に試してください)")
    bold_label.setWrapText(true)
    items << [ bold_label ,
               @bold_check 
             ]
    
    items.each_with_index{|row , rownum|
      row.each_with_index{|control , colnum|
        GridPane.setColumnIndex( control , colnum )
        GridPane.setRowIndex( control , rownum )
        
        GridPane.setMargin( control , Insets.new( 5 , 5 , 5 , 5))
        grid_pane.getChildren().add( control )
      }
    }

    column_1 = ColumnConstraints.new(350)
    column_2 = ColumnConstraints.new(350)
    #column_1.setPercentWidth( 50 )
    #column_2.setPercentWidth( 50 )
    column_1.setHalignment( HPos::RIGHT )
    column_2.setHalignment( HPos::LEFT  )
    grid_pane.getColumnConstraints().addAll(column_1, column_2)

    label_top = Label.new("設定の反映にはだいたい再起動が必要です")
    label_top.setStyle("-fx-font-size:16px")
    getChildren.add( label_top )
    getChildren.add( scroll_pane )

    prepare_tab( "設定" )
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
