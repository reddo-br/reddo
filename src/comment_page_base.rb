# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'app'
require 'page'

import 'javafx.application.Platform'

class CommentPageBase < Page
  
  def open_edit_area
    if not @edit_ime_prepared
      App.i.tab_pane.requestFocus # editを開く前にwebviewからフォーカスを外さないとimeがバグる javafx8
    end
    
    if @split_pane.getItems().size == 1
      @split_edit_area.setVisible(true)
      @split_pane.getItems().add( @split_edit_area )
    end
      
    Thread.new{
      if not @edit_ime_prepared
        tp = App.i.tab_pane
        60.times{|c|
          sleep(0.05)
          if tp.isFocused
            $stderr.puts "ime 問題フォーカス待ち #{c}回目"
            break
          end
         }
      end
      Platform.runLater{ 
        @split_edit_area.focus_input 
        @edit_ime_prepared = true
      }
    }
  end

  def close_edit_area
    @split_edit_area.setVisible( false )
    @split_pane.getItems().remove( 1 , 2 )
    
    target = @replying || @editing
    if target
      @comment_view.clear_replying( target[:name] )
    end
    @replying = @editing = nil
  end

  def set_load_button_enable2( enable , start_buttons , stop_buttons )
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
    Platform.runLater{
      @split_edit_area.set_error_message("")
      close_edit_area
    }
  end
  
  def edit( obj_edit , md_text )
    set_load_button_enable( false )
    cl = App.i.client( @account_name ) # refresh
    comm = obj_edit.edit( md_text ) # commのbody_htmlは変更されない、注意
    comm = obj_edit.client.from_fullname( obj_edit[:name] ).to_a[0] # 再取得
    comm = obj_edit.merge( comm ) # user履歴上のcommentの情報を維持する
    Platform.runLater{
      if comm[:kind] == 't3'
        @comment_view.set_submission( comm )
      else
        @comment_view.add_comment( comm , recursive:false , prepend:true)
      end
      @comment_view.set_link_hook
    }
    Platform.runLater{
      @split_edit_area.set_error_message("")
      close_edit_area
    }
  end

  DELETED_HTML_JSONSTR = "&lt;div class=\"md\"&gt;&lt;p&gt;[deleted]&lt;/p&gt;\n&lt;/div&gt;"
  def delete( obj , show_delete_element:true)
    set_load_button_enable( false )
    cl = App.i.client( @account_name )
    obj.delete!
    obj[:author] = '[deleted]'
    Platform.runLater{
      if obj[:kind] == 't3'
        if obj[:is_self]
          obj[:selftext] = '[deleted]'
          obj[:selftext_html] = DELETED_HTML_JSONSTR
        end
        @comment_view.set_submission( obj )
      else

        if show_delete_element
          obj[:body] = '[deleted]'
          obj[:body_html] = DELETED_HTML_JSONSTR
          @comment_view.add_comment( obj , recursive:false , prepend:true)
        else
          @comment_view.remove_comment( obj[:name] )
        end

      end
      
    }
  end
  
  def object_to_deep( listing_ary ,depth = 0 )
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

  def on_select
    App.i.set_url_area_text( @base_url.to_s )
  end

end # class
