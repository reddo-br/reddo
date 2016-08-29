# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'preview_web_view_wrapper'
# require 'kramdown_reddit'
require 'app'

class EditWidget < Java::JavafxSceneLayout::VBox
  include JRubyFX::DSLControl

  def initialize( account_name:nil , site:"reddit" , sjis_art:true , subname:nil)
    # t3(submission) とt1(comment)の違い
    # Submission#add_comment
    # Commnet#reply (inboxable)
    super()
    @account_name = account_name # リンクの判定のみに使っている
    @subname = subname
    @url_handler = UrlHandler.new( account_name:account_name )
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

    @toolbar.getChildren().addAll( Label.new(" ") ,
                                   Separator.new(Orientation::VERTICAL),
                                   Label.new(" "))

    @code_indent_button = Button.new("AA/CODE" , GlyphAwesome.make("INDENT"))
    @code_indent_button.setTooltip( Tooltip.new("行頭にスペースを4つ挿入します"))
    @code_indent_button.setOnAction{|e|
      code_indent
    }
    @toolbar.getChildren().add(@code_indent_button)

    @toolbar.getChildren().addAll( Label.new(" ") ,
                                   Separator.new(Orientation::VERTICAL),
                                   Label.new(" "))

    @post_button = Button.new("返信" , GlyphAwesome.make("REPLY"))
    @post_button.setOnAction{|e| 
      if @post_cb
        @post_cb.call( get_md )
      end
    }
    @toolbar.getChildren().add( @post_button )
    @close_button = Button.new("閉じる" , GlyphAwesome.make("CLOSE"))
    @close_button.setOnAction{|e|
      @close_cb.call if @close_cb
    }

    @toolbar.getChildren().add( @close_button )
    @toolbar.getChildren().add( Label.new(" "))
    
    App.i.adjust_height( @toolbar.getChildren().to_a , @post_button )

    @toolbar2 = BorderPane.new
    @toolbar2.setLeft( @toolbar )
    BorderPane.setAlignment( @toolbar , Pos::CENTER_LEFT )
    
    @error_label = Label.new("")
    @error_label.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_RED}")
    @toolbar2.setCenter( @error_label )
    BorderPane.setAlignment( @error_label , Pos::CENTER_LEFT )

    add( @toolbar2 )
    self.class.setMargin( @toolbar2 , Insets.new( 3 , 3 , 3 , 3 ))

    @text_area = TextArea.new
    App.i.suppress_printable_key_event( @text_area )
    @text_area.setWrapText(true)
    add( @text_area )

    @preview = PreviewWebViewWrapper.new( sjis_art:sjis_art ){
      # prepared
      $stderr.puts "プレビューwebview 準備完了"
    }
    
    @preview.set_link_cb{|link|
      page_info = @url_handler.url_to_page_info( link )
      page_info[:account_name] = @account_name
      App.i.open_by_page_info( page_info )
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
      Platform.runLater{ # js対策
        show_preview
      }
    }
    @mode = nil

  end # initialize
  def set_account_name(an)
    @account_name = an
  end

  def set_text( text , mode:"reply" )
    @text_area.setText( text )
    @mode = mode
    if @mode == 'reply'
      @text_mode_button.setDisable(false)
      # @text_mode_button.setSelected(true) # todo: デフォルト設定
      @md_mode_button.setSelected(true)
      @post_button.setText("返信")
      @post_button.setGraphic( GlyphAwesome.make("REPLY"))
    else
      @md_mode_button.setSelected(true)
      @text_mode_button.setDisable(true)
      @post_button.setText("編集")
      @post_button.setGraphic( GlyphAwesome.make("EDIT"))
    end
  end

  def focus_input
    @text_area.requestFocus
  end

  def set_sub_link_style( style )
    @preview.set_additional_style( style )
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
        Util.escape_md( line ) + "  "
      end
    }.join("\n")
  end

  def set_post_disable
    @post_button.setDisable(true)
  end

  def set_post_enable
    @post_button.setDisable(false)
  end
  
  def set_error_message(mes)
    @error_label.setText(mes.to_s)
  end

  def code_indent
    text = @text_area.getText()
    lines = text.split(/\n/ , -1)
    if index_range = @text_area.getSelection()
      st = index_range.getStart()
      ed = index_range.getEnd()
      $stderr.puts "range: #{st}:#{ed}"
      replace_lines = []
      cur_pos = 0
      repl_st = nil
      repl_ed = nil
      lines.each{ |l|
        if st <= (cur_pos + l.length) and cur_pos <= ed
          replace_lines << "    " + l
          if repl_st == nil or cur_pos < repl_st
            repl_st = cur_pos
          end
          if repl_ed == nil or repl_ed < (cur_pos + l.length)
            repl_ed = cur_pos + l.length
          end
        end
        cur_pos += (l.length + 1)
      }
      new_text = replace_lines.join("\n")
      # undoのバグ回避
      new_text2 = new_text.gsub(/[^ ]+\Z/,'')
      repl_ed -= ( new_text.length - new_text2.length )

      @text_area.replaceText( repl_st, repl_ed , new_text2 )
    end
    
  end

  attr_reader :post_button

end

