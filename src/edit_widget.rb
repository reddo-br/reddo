# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'preview_web_view_wrapper'
# require 'kramdown_reddit'

class EditWidget < Java::JavafxSceneLayout::VBox
  include JRubyFX::DSLControl

  def initialize( account_name:nil , site:"reddit" , sjis_art:true )
    # t3(submission) とt1(comment)の違い
    # Submission#add_comment
    # Commnet#reply (inboxable)
    super()
    
    @text_mode_button = ToggleButton.new("Text")
    @md_mode_button =   ToggleButton.new("Markdown")
    mode_buttons = [ @text_mode_button , @md_mode_button ]

    @mode_toggle_group = ToggleGroup.new
    mode_buttons.each{|b| b.setToggleGroup( @mode_toggle_group ) }
    
    Util.toggle_group_set_listener_force_selected( @mode_toggle_group,
                                                   @text_mode_button ){|btn|
      show_preview
    }
    
    # @toolbar = ToolBar.new
    @toolbar = HBox.new(2.0)
    @toolbar.setAlignment( Pos::CENTER_LEFT )
    @toolbar.getChildren().addAll( mode_buttons )
    # App.i.make_pill_buttons( mode_buttons )

    @toolbar.getChildren().add( Label.new(" ") )

    @post_button = Button.new("返信")
    @post_button.setOnAction{|e| 
      if @post_cb
        @post_cb.call( get_md )
      end
    }
    @toolbar.getChildren().add( @post_button )
    @close_button = Button.new("閉じる")
    @close_button.setOnAction{|e|
      @close_cb.call if @close_cb
    }

    @toolbar.getChildren().add( @close_button )

    add( @toolbar )
    self.class.setMargin( @toolbar , Insets.new( 3 , 3 , 3 , 3 ))

    @text_area = TextArea.new
    @text_area.setWrapText(true)
    add( @text_area )

    @preview = PreviewWebViewWrapper.new( sjis_art:sjis_art ){
      # prepared
      $stderr.puts "プレビューwebview 準備完了"
    }
    @preview_label = Label.new("プレビュー")
    add( @preview_label)
    add( @preview.webview )

    # リサイズ
    heightProperty.addListener{|ov|
      height = ov.getValue()

      height_to_edit = height - @toolbar.getHeight() - @preview_label.getHeight()
      @text_area.setPrefHeight( height_to_edit / 2 )
      @preview.webview.setPrefHeight( height_to_edit / 2 )
    }

    @text_area.textProperty.addListener{|ov|
      show_preview
    }
    @mode = nil
  end

  def set_text( text , mode:"reply" )
    @text_area.setText( text )
    @text_area.requestFocus
    @mode = mode
    if @mode == 'reply'
      @text_mode_button.setDisable(false)
      # @text_mode_button.setSelected(true) # todo: デフォルト設定
      @md_mode_button.setSelected(true)
      @post_button.setText("返信")
    else
      @md_mode_button.setSelected(true)
      @text_mode_button.setDisable(true)
      @post_button.setText("編集")
    end
  end

  def set_close_cb(&cb)
    @close_cb = cb
  end

  def set_post_cb(&cb)
    @post_cb = cb
  end

  def show_preview
    @preview.set_md( get_md )
    @preview.set_link_hook
  end

  def get_md
    md = @text_area.getText()
    case @mode_toggle_group.getSelectedToggle()
    when @text_mode_button
      text_to_md(md)
    when @md_mode_button
      md
    end
  end

  def text_to_md( text )
    text.split(/\r?\n/o).map{|line|
      if line.strip.length == 0
        "&nbsp;  "
      else
        escape_md( line ) + "  "
      end
    }.join("\n")
  end

  def escape_md( line )
    # html escapeする
    str1 = line.dup
    str1.gsub!(/\&/o , "&amp;")
    str1.gsub!(/\>/o , "&gt;")
    str1.gsub!(/\</o , "&lt;")
    str1.gsub!(/^ +/){|m|
      "&nbsp;" * m.length
    }
    str1.gsub!(/ {2,}/){|m|
      "&nbsp;" * m.length
    }

    url_positions = []
    pos = 0
    while pos < str1.length
      if m = str1.match(/(https?|ftp):\/\/\w+/o , pos)
        url_positions << [ m.begin(0) , m.end(0) ]
        pos = m.end(0)
      else
        break
      end
    end

    # . はエスケープしない
    # url内部でのエスケープを止めたい
    str1.gsub!( /[\`\*_\{\}\[\]\(\)\#\+\-\!\^\~\>\\]/o ){ |c| 
      m = Regexp.last_match
      pos = m.begin(0)
      if url_positions.find{|b,e| b <= pos and pos < e }
        c
      else
        "\\" + c
      end
    }
    str1
  end

  def set_post_disable
    @post_button.setDisable(true)
  end

  def set_post_enable
    @post_button.setDisable(false)
  end
end

