# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'
require 'reddit_web_view_wrapper'
require 'html/html_entity'
require 'thumbnail_plugins'

import 'javafx.scene.control.SeparatorMenuItem'
import 'javafx.scene.control.CheckMenuItem'

class CommentWebViewWrapper < RedditWebViewWrapper

  def initialize(sjis_art:true , &dom_prepared_cb)
    super(sjis_art:sjis_art , &dom_prepared_cb)

    @upvote_img_url   = App.res_url( "/res/upvote.png")
    @downvote_img_url = App.res_url( "/res/downvote.png")
    @upvoted_img_url   = App.res_url( App.i.theme::HTML_UPVOTED)
    @downvoted_img_url = App.res_url( App.i.theme::HTML_DOWNVOTED)

    $stderr.puts "internal url upvote #{@upvote_img_url}"

    @self_text_visible = true
    
    @hard_ignored_item = {}
    @fold_state = {}

  end
  attr_reader :webview
  attr_accessor :use_user_flair_style
  
  
  def dom_prepared(ov)
    super(ov)
    @div_submission = @doc.getElementById("submission")
    @div_comments   = @doc.getElementById("comments")
    
    @doc.getElementById("top").setAttribute("style" , "font-size:#{@base_font_zoom}%") if @base_font_zoom
    # @e.executeScript( JS_SCROLL_ELEMENT_IN_VIEW )
  end

  def set_font_zoom( percent )
    if( @base_font_zoom != percent )
      @base_font_zoom = percent
      if @doc
        top_comment_id = get_current_screen_top_comment_id
        if percent
          @doc.getElementById("top").setAttribute("style" , "font-size:#{@base_font_zoom}%")
          line_image_resize( percent )
        else
          @doc.getElementById("top").setAttribute("style" , "")
          line_image_resize( nil )
        end
        scroll_to_id( top_comment_id , animation:false) if top_comment_id
      end
    end
  end
  
  def line_image_resize( percent )
    # transformだとレイアウトに反映されない
    css = if percent
            ratio = percent / 100.0
            "width:#{16*ratio}px; height:#{16*ratio}px;"
          else
            ""
          end
    @e.executeScript( <<EOF )
$('.image_for_resize').attr('style','#{css}');
EOF
  end

  def set_vote_cb
    @vote_cb = Proc.new
  end

  def set_reply_cb(&cb)
    @reply_cb = cb
  end

  def set_edit_cb(&cb)
    @edit_cb = cb
  end

  def set_delete_cb(&cb)
    @delete_cb = cb
  end

  def set_hide_cb(&cb)
    @hide_cb = cb
  end
  
  def set_save_cb(&cb)
    @save_cb = cb
  end

  def set_account_name( name )
    @account_name = name
  end

  def set_account_is_moderator( b )
    @account_is_moderator = b
  end
  
  def set_user_suspended( suspended )
    @user_suspended = suspended
  end

  def set_url_handler( uh )
    @uh = uh
  end

  def set_title(title , link = nil , selftext = false)
    dom_title = @doc.getElementById("linked-title")
    dom_title.setMember("innerHTML" , title )

    if selftext
      dom_title.setAttribute("style" , "pointer-events: none;cursor: default;")
    else
      dom_title.setAttribute("href" , link.to_s )
      dom_title.setAttribute("style" , "")
    end
  end

  def set_submission(obj)
    @original_poster = obj[:author]
    @permalink = obj[:permalink]
    @locked = obj[:locked]
    @link_id = obj[:name]

    prepare_submission_switch

    set_title( html_decode(obj[:title].to_s) , html_decode(obj[:url]) , obj[:is_self])
    domain = @doc.getElementById("domain")
    domain.setMember("innerHTML" , "(" + obj[:domain] + ")" )
    
    subreddit_url = @uh.subname_to_url( obj[:subreddit] ).to_s
    subreddit_info = @doc.getElementById("subreddit")
    empty("#subreddit")
    # subreddit_info.setMember("innerHTML","")
    subreddit_link = @doc.createElement("a")
    subreddit_link.setMember("innerHTML" , obj[:subreddit].to_s )
    subreddit_link.setAttribute("href" , subreddit_url )
    subreddit_link.setAttribute("class" , "title-subreddit-link" )
    subreddit_info.appendChild( @doc.createTextNode("["))
    subreddit_info.appendChild( subreddit_link )
    subreddit_info.appendChild( @doc.createTextNode("]"))

    #subm_switch = @doc.getElementById("submission-switch")
    #subm_switch.setTextContent("[-]") #
    if @link_id
      subm_text_closed = ReadCommentDB.instance.get_closed( "st_" + @link_id )
      submission_text_expand( (not subm_text_closed))
    end
    
    crosspost_link_area = @doc.getElementById("crosspost-links")
    empty("#crosspost-links")
    if obj[:crosspost_parent_list] and obj[:crosspost_parent_list].length > 0
      # p "＊＊ crosspost_parent_list #{obj[:crosspost_parent_list]}"
      crosspost_link_area.setMember("innerHTML" , "クロスポスト:<br>")
      obj[:crosspost_parent_list].each{|ln|
        cl = @doc.createElement("span")
        # cl.setAttribute("style","padding-left:1em;")
        cl_t = @doc.createElement("a")
        cl_t.setMember("innerHTML" , ln[:title].to_s )
        cl_t.setAttribute("href" , ln[:permalink] )
        cl_t.setAttribute("class" , "link-title" )

        cl_r = @doc.createElement("a")
        cl_r.setMember("innerHTML" , ln[:subreddit].to_s )
        subreddit_url = @uh.subname_to_url( ln[:subreddit] ).to_s
        cl_r.setAttribute("href" , subreddit_url )
        cl_r.setAttribute("class" , "title-subreddit-link" )

        cl.appendChild( cl_t )
        cl.appendChild( @doc.createTextNode("["))
        cl.appendChild( cl_r )
        cl.appendChild( @doc.createTextNode("]"))
        cl.appendChild( @doc.createElement("br"))
        crosspost_link_area.appendChild( cl )
      }
      
    end
    
    subm = @doc.getElementById("submission")
    if obj[:is_self] and @self_text_visible and obj[:selftext_html].to_s.length > 0
      # $stderr.puts "*** selfテキスト表示"
      # $stderr.puts obj[:selftext_html]
      subm.setAttribute("style","display:block")
      selftext_html = if App.i.pref["suppress_combining_mark"]
                        obj[:selftext_html].gsub(/(\p{M})+/,'\1')
                      else
                        obj[:selftext_html]
                      end

      subm_text = @doc.getElementById("submission-text")
      empty("#submission-text")
      text_wrapper = @doc.createElement("div")

      style_class = ""
      style_class += " use_link_style" if @use_link_style
      style_class += " use-sjis-art" if @sjis_art
      text_wrapper.setAttribute("class",style_class)

      text_wrapper.setMember( "innerHTML" , html_decode( selftext_html.to_s ))
      subm_text.appendChild(text_wrapper)

      if thumb = make_thumbnail_element( subm_text )
        subm_text.appendChild( thumb )
      end
    else
      subm.setAttribute( "style","display:none")
      # subm.setMember("innerHTML" , "") # :empty -> display:none
    end

    subm_head = make_post_head_element( obj , true )
    
    sh = @doc.getElementById("subm-head")
    empty("#subm-head")
    # sh.setMember("innerHTML" , "" )
    sh.appendChild( subm_head )

    flair = @doc.getElementById("link-flair")
    
    lf = if obj[:link_flair_type] == 'richtext'
           flair_richtext_to_html( obj[:link_flair_richtext] )
         else
           html_decode(obj[:link_flair_text].to_s)
         end
    flair.setMember("innerHTML" , lf)
    color_style = ""
    if obj[:link_flair_background_color].to_s.length > 0
      color_style = "background-color: #{obj[:link_flair_background_color]};"
      # この色はreddoテーマに依存してはならない…
      if obj[:link_flair_text_color] == 'light'
        color_style += "color: #eeeeee; "
      elsif obj[:link_flair_text_color] == 'dark'
        color_style += "color: #222222; "
      end
    end
    
    # :emptyがうまく動作しない
    if(lf.length > 0)
      flair.setAttribute("style","display:inline; #{color_style}")
    else
      flair.setAttribute("style","display:none; #{color_style}")
    end

    img = @doc.getElementById("preview")
    imgb = @doc.getElementById("preview-box")

    if obj[:is_self]
      img.setAttribute("style" , "visibility:hidden")
      imgb.setAttribute("style" , "visibility:hidden")
    else
      
      image_url , w, h = Util.find_submission_preview( obj , 
                                                       max_width:300 , max_height:200 ,
                                                       prefer_large:true)
      if image_url
        img.setAttribute("style" , "visibility:visible")
        img.setAttribute("src" , html_decode(image_url))
        #imgb.setAttribute("width" , w.to_s )
        #imgb.setAttribute("height" , h.to_s )
        imgb.setAttribute("style" , "width:#{w}px; height:#{h}px;")
      else
        if obj[:thumbnail].to_s =~ /^http/
          img.setAttribute("style" , "visibility:visible")
          img.setAttribute("src" , html_decode(obj[:thumbnail]))
          # imgb.setAttribute("style", "width:140px; height:140px;")
          imgb.setAttribute("style", "width:140px; ")
        else
          img.setAttribute("style" , "visibility:hidden")
          imgb.setAttribute("style" , "visibility:hidden")
        end
      end
      
    end

    foot = make_footer_element( nil , obj )
    command = @doc.getElementById("submission-command")
    # command.setMember("innerHTML" , "" )
    empty("#submission-command")
    command.appendChild( foot )
  end
  
  def prepare_submission_switch
    if not @submission_switch_prepared
      sw = @doc.getElementById("submission-switch")
      set_event( sw , "click" , false , free_explicitly:false){
        if @link_id
          ReadCommentDB.instance.set_closed( "st_" + @link_id , @submission_expanded)
        end
        submission_text_expand( (not @submission_expanded) )
        
      }
      @submission_switch_prepared = true
    end
  end

  def submission_text_expand( expand )
    text = @doc.getElementById( "submission-text")
    sw = @doc.getElementById("submission-switch")
    mes = @doc.getElementById("submission-switch-message")
    if expand
      @submission_expanded = true
      text.setAttribute("style","display:block")
      sw.setTextContent("[-]")
      mes.setTextContent("")
    else
      @submission_expanded = false
      text.setAttribute("style","display:none")
      sw.setTextContent("[+]")
      mes.setTextContent("閉じられた投稿テキスト")
    end
  end

  def find_first_child( comment_node , allow_sticky:false )
    children = comment_node.getChildNodes()
    ret = nil
    (0).upto( children.getLength() - 1 ){|n|
      node = children.item(n)
      node_id = node.getAttribute("id")
      if node_id !~ /^ct_/ # 自分以外
        if allow_sticky or not is_sticky_node_id( node_id )
          ret = node
          break
        end
      end
    }
    return ret
  end

  def is_sticky_node_id( node_id )
    nn = @e.executeScript("$(\"##{node_id} .sticky-mark\").length")
    $stderr.puts "is_sticky_node #{nn}"
    nn > 0
  end

  def set_more_cb( &cb )
    @more_cb = cb
  end

  def more_result( more_elem_id , success )
    more = @doc.getElementById( more_elem_id ) # うまくいかない
    # more = elem

    $stderr.puts "more_result more_element_id: #{more_elem_id}"
    $stderr.puts "more_result more: #{more}"

    if success
      # more.getParentNode().removeChild( more )
      remove( "##{more_elem_id}" )
    else
      more.getChildNodes().item(0).removeAttribute("disabled")
      more.getChildNodes().item(1).setTextContent("取得失敗")
    end
  end

  def add_comment( obj , parent = nil , recursive:true , prepend:false )
    parent = @doc.getElementById("cs_" + parent) if parent.is_a?(String)

    if not parent or obj.is_a?(Redd::Objects::MoreComments) # moreは階層の中に入ってないこともある
      if obj.kind_of?(Hash)
        if obj[:reddo_ignored] == IgnoreScript::HARD_IGNORE and obj[:author] != @account_name
          @hard_ignored_item[ obj[:name] ] = true
          return
        end
        
        parent_id = obj[:parent_id]
        if @hard_ignored_item[ parent_id ]
          @hard_ignored_item[ obj[:name] ] = true
          return
        elsif parent_id =~ /^t3/
          parent = @doc.getElementById("comments")
        elsif parent_id
          # parent = @doc.getElementById( parent_id )
          parent = @doc.getElementById( "cs_" + parent_id )
        end
        
        # 部分コメント用 いちおうトップにしておく
        parent ||= @doc.getElementById("comments")
      else # MoreCommentなど
        parent_id = obj.parent_id
        if parent_id =~ /^t3/
          parent = @doc.getElementById("comments")
        else
          parent = @doc.getElementById("cs_" + parent_id) # moreは階層の中に入ってないこともある
        end
      end
    end

    if parent
      # if obj.kind_of?(Array)
      if obj.is_a?( Redd::Objects::MoreComments )
        if obj.count > 0

          more , more_button , elem_id , result = create_more_element( "もっと見る(#{obj.count})" )
          parent.appendChild( more )
          
          if @account_name
            set_event(more_button , 'click',false){
              if @more_cb
                more_button.setAttribute("disabled" , "disabled" )
                Platform.runLater{
                  # @more_cb.call( obj , more )
                  @more_cb.call( obj , elem_id )
                }
              end
            }
          else
            more_button.setAttribute("disabled" , "disabled" )
            result.setTextContent("※現状Reddoでは、アカウントを設定しないと「もっと見る」が機能しません")
          end
        else # 自分自信がchildであるようなmore
          # 階層が深すぎるのか？
          continue_thread = @doc.createElement("div")
          continue_thread.setAttribute("class","more")
          url = @permalink + obj.parent_id.gsub(/^t\d_/,'')
          link = @doc.createElement("a")
          link.setAttribute("href" , url )
          link.setTextContent("スレッドの続き…")
          continue_thread.appendChild( link )
          parent.appendChild( continue_thread )
        end

      else # obj.is_a?( Redd::Objects::MoreComments )

        old_comment_this = @doc.getElementById( "ct_" + obj[:name].to_s )
        # comment_this = make_comment_this_element( obj )
        if old_comment_this
          old_comment_this.setAttribute("id" , "") # id重複を避ける
          comment_this = if obj[:kind] == 't3'
                           make_post_in_list_inner_element(obj)
                         else
                           make_comment_this_element( obj )
                         end
          comment_shown = old_comment_this.parentNode()
          comment_shown.replaceChild( comment_this, old_comment_this )
        else
          comment_this = if obj[:kind] == 't3'
                           make_post_in_list_inner_element(obj)
                         else
                           make_comment_this_element( obj )
                         end
          comment = @doc.createElement("div")
          comment.setAttribute("id" , obj[:name])

          if obj[:kind] == 't3'
            comment.setAttribute("class",  "post-in-list")
          else
            comment.setAttribute("class" , "comment")
          end
          
          comment_hidden = create_comment_hidden_block(obj)
          comment_shown  = create_comment_shown_block(obj)
          if is_to_fold_object(obj)
            comment_hidden.setAttribute("style","display:block")
            comment_shown.setAttribute("style","display:none")
            @fold_state[ obj[:name] ] = {:folded => true , :parent => obj[:parent_id] }
          else
            comment_hidden.setAttribute("style","display:none")
            comment_shown.setAttribute("style","display:block")
            @fold_state[ obj[:name] ] = {:folded => false , :parent => obj[:parent_id] }
          end
          comment.appendChild( comment_hidden )
          comment.appendChild( comment_shown )

          comment_shown.appendChild( comment_this )
          if prepend
            parent.insertBefore( comment , find_first_child( parent ))
          else
            parent.appendChild( comment )
          end
        end
        
        if recursive
          # puts "再帰"
          # p obj[:replies].class # なぜかListingではなくhash <- 変換されてない <- 呼び出し側で再帰的に変換しとく
          if children = obj[:replies] and children.class == Redd::Objects::Listing
            children.each{|cc|
              # p cc
              add_comment( cc , comment_shown , recursive:recursive , prepend:prepend )
            }
          end
        end
      end
    end

  end # add_comment

  def is_to_fold_object(obj)
    (obj[:reddo_ignored] == IgnoreScript::IGNORE and obj[:author] != @account_name) or 
      ReadCommentDB.instance.get_closed( obj[:name] )
  end

  def is_folded?( name )
    if st = @fold_state[ name ]
      # $stderr.puts "is_folded? #{st}"
      if st[ :folded ]
        true
      else
        if st[ :parent ]
          is_folded?( st[ :parent ] )
        else
          # 頂点までたぐった
          false
        end
      end
    else
      false
    end
  end

  def comment_expand( id , expand )
    comment = @doc.getElementById( id )
    if comment
      child_nodes = comment.getChildNodes()
      hidden = child_nodes.item(0)
      shown  = child_nodes.item(1)

      st = @fold_state[ id ]
      if expand
        hidden.setAttribute("style","display:none")
        shown.setAttribute("style","display:block")
        if st
          st[:folded] = false
        end
        remove_class( comment , "tree_closed" )
      else
        hidden.setAttribute("style","display:block")
        shown.setAttribute("style","display:none")
        if st
          st[:folded] = true
        end
        add_class( comment , "tree_closed" )
      end

    end
  end
  
  # 結局使ってない
  def find_child_comments( name )
    script = "$('##{name}').find('.comment-this').map(function(){return $(this).prop('id');});"
    jsarray = @e.executeScript( script )
    ret = []
    $stderr.puts "length:#{jsarray.getMember('length')}"
    0.upto( jsarray.getMember( 'length' ) - 1 ){|i|
      ret << jsarray.getSlot(i)
    }
    ret
  end

  def create_comment_hidden_block(obj)
    comment_hidden = @doc.createElement("div")
    comment_hidden.setAttribute("class","comment-hidden")
    comment_hidden.setAttribute("id" , "ch_" + obj[:name].to_s )
    
    comment_hidden_switch = @doc.createElement("span")
    comment_hidden_switch.setAttribute("class" , "close-switch")
    comment_hidden_switch.setTextContent("[+]")
    set_event( comment_hidden_switch , "click" , false ) {
      ReadCommentDB.instance.set_closed( obj[:name] , false )
      comment_expand( obj[:name] , true )
      # todo: ignoreでなければ、dbに状態を書き込む
    }
    comment_hidden.appendChild( comment_hidden_switch )

    comment_hidden.appendChild( @doc.createTextNode("閉じられたコメント"))


    comment_hidden_reason = @doc.createElement("span")
    comment_hidden_reason.setAttribute("class","comment-hidden-reason")
    if obj[:reddo_ignored] == IgnoreScript::IGNORE
      comment_hidden_reason.setTextContent("[Ignored]")
    else
      comment_hidden_reason.setTextContent("[手動]")
    end
    comment_hidden.appendChild( comment_hidden_reason )

    # 高さを合わせる
    dummy_arrow_image = @doc.createElement("img")
    # dummy_arrow_image.setAttribute("src",@upvoted_img_url)
    dummy_arrow_image.setAttribute("class","dummy-arrow image_for_resize")
    comment_hidden.appendChild( dummy_arrow_image )
    
    comment_hidden
  end

  def create_comment_shown_block( obj )
    comment_shown = @doc.createElement("div")
    comment_shown.setAttribute("class","comment-shown")
    comment_shown.setAttribute("id" , "cs_" + obj[:name].to_s )
    comment_shown
  end

  def add_list_more_button
    comments = @doc.getElementById("comments")

    more , more_button , elem_id , result = create_more_element

    set_event( more_button , 'click' ,false ){
      if @more_cb
        more_button.setAttribute("disabled" , "disabled" )
        Platform.runLater{
          @more_cb.call( nil , elem_id )
        }
      end
    }

    comments.appendChild( more )
  end
  
  def create_more_element( label = "もっと見る" )
    more = @doc.createElement("div")
    more.setAttribute("class" , "more")
    elem_id = java.util.UUID.randomUUID().toString()
    more.setAttribute("id" , elem_id)
    more_button = @doc.createElement("button")
    more_button.setTextContent(label)
    more.appendChild( more_button )

    result = @doc.createElement("span")
    more.appendChild( result )

    [ more , more_button , elem_id , result]
  end

  def remove_comment( name )
    element_id = name # そのまま
    target = @doc.getElementById( element_id )
    if target
      # empty( "#" + element_id )
      # target.getParentNode().removeChild( target )
      remove( "#" + element_id )
    end
  end

  def clear_comment
    clear_events # web_view_wrapper.rb # イベントリスナーの明示的解放
    # set_message(nil) # 消さない
    @hard_ignored_item = {}
    @fold_state = {}

    # @div_comments.setMember("innerHTML" , "")
    # @div_submission.setMember("innerHTML","")
    empty("#submission-text")
    empty("#comments")
    
    #if t = @doc.getElementById("linked-title")
    #  t.setMember("innerHTML" , "")
    #end
    empty("#linked-title")
    empty("#domain")
    empty("#subreddit")
    # todo: submissionも複数に対応する
    # @doc.getElementById("subm-head").setMember("innerHTML","")
    if pv = @doc.getElementById("preview")
      pv.setAttribute("src","")
    end
    # @doc.getElementById("link-flair").setMember("innerHTML","")
    # @doc.getElementById("submission-command").setMember("innerHTML","")

    empty("#subm-head")
    empty("#link-flair")
    empty("#submission-command")

  end

  def make_comment_this_element( obj )
    #comment = @doc.createElement("div")
    #comment.setAttribute("id" , obj[:name])
    #comment.setAttribute("class" , "comment")

    comment_this = @doc.createElement( "div")
    comment_this.setAttribute("class" , "comment-this")
    comment_this.setAttribute("id" , "ct_" + obj[:name].to_s )

    if @comment_post_list_mode
      link_area = @doc.createElement("div")
      link_area.setAttribute("class","user-history-comment-header")
      post_link = @doc.createElement("a")
      post_link.setAttribute("href" , html_decode(obj[:link_url]))
      post_link.setMember("innerHTML", html_decode(obj[:link_title]))
      post_link.setAttribute("class" , "link-title")

      link_area.appendChild( post_link )

      link_area.appendChild( @doc.createTextNode(" ["))
      
      sub_link = @doc.createElement("a")
      sub_link.setMember("innerHTML" , obj[:subreddit].to_s )
      sub_link.setAttribute("href" , @uh.subname_to_url( obj[:subreddit]).to_s )
      sub_link.setAttribute("class" , "title-subreddit-link" )
      link_area.appendChild( sub_link )
      
      link_area.appendChild( @doc.createTextNode("]"))

      comment_this.appendChild( link_area )
    end

    comm_head = make_post_head_element( obj )
    comment_this.appendChild( comm_head )

    comment_text = @doc.createElement("div")
    style_class = ""
    style_class += " use_link_style" if @use_link_style
    style_class += " use-sjis-art" if @sjis_art
    
    comment_text.setAttribute("class" , "comment_text#{style_class}")
    body_html = if App.i.pref["suppress_combining_mark"]
                  obj[:body_html].gsub(/(\p{M})+/ , '\1')
                else
                  obj[:body_html]
                end
    comment_text.setMember("innerHTML" , html_decode(body_html.strip) )
    
    comment_this.appendChild( comment_text )

    if thumb_area = make_thumbnail_element( comment_text )
      comment_this.appendChild( thumb_area )
    end
    
    comment_foot = make_footer_element( comment_this , obj )
    comment_this.appendChild( comment_foot )
    # comment.appendChild( comment_this )
    
    comment_this
  end

  def make_post_in_list_inner_element( obj )
    post = @doc.createElement("div")
    post.setAttribute("class","post-in-list-inner")
    post.setAttribute("id" , "ct_" + obj[:name].to_s )
    
    post_head = make_post_head_element( obj )
    post.appendChild( post_head )
    
    # thumb

    post_title = @doc.createElement("div")
    
    thumb_url , w , h = Util.decoded_thumbnail_url( obj )
    if thumb_url
      thumb = @doc.createElement("img")
      thumb.setAttribute("class","post-thumb-in-list")
      thumb.setAttribute("src" , thumb_url )
      post_title.appendChild( thumb )
    end

    post_title.appendChild( make_link_title_in_list(obj))
    post.appendChild( post_title )

    num_comments = @doc.createElement("div")
    num_comments.setTextContent("#{obj[:num_comments]}コメント")
    post.appendChild( num_comments )

    c = @doc.createElement("div")
    c.setAttribute("style","clear:both")
    post.appendChild( c )

    post_footer = make_footer_element( post , obj )
    post.appendChild( post_footer )

    post
  end

  # todo: いずれset_submissionと統合する
  def make_link_title_in_list( obj )
    linked_title_area = @doc.createElement("span")
    linked_title = @doc.createElement("a")
    linked_title.setAttribute("class","link-title")
    linked_title.setAttribute("href", html_decode( obj[:url] ) )
    linked_title.setMember("innerHTML" , html_decode(obj[:title].to_s))
    linked_title_area.appendChild( linked_title )

    domain = @doc.createElement("span")
    domain.setMember( "innerHTML" , " (" + obj[:domain] + ")" )
    linked_title_area.appendChild( domain )

    subreddit_link = @doc.createElement("a")
    subreddit_link.setMember("innerHTML" , obj[:subreddit].to_s )
    subreddit_url = @uh.subname_to_url( obj[:subreddit] ).to_s
    subreddit_link.setAttribute("href" , subreddit_url )
    subreddit_link.setAttribute("class" , "title-subreddit-link" )

    linked_title_area.appendChild( @doc.createTextNode(" ["))
    linked_title_area.appendChild( subreddit_link )
    linked_title_area.appendChild( @doc.createTextNode("]"))

    linked_title_area
  end

  def make_thumbnail_element( elem )
    anchors = nl2a(elem.getElementsByTagName("a"))
    # anchors.uniq!{|a| a.getAttribute("href").to_s } # 同じ画像は見ない
    anchors_with_thumb = anchors.inject([]){|ret,anchor| 
      href = anchor.getAttribute("href").to_s
      if href.length > 0
        thumb_html = nil
        ThumbnailPlugins.instance.plugins.each{|p|
          if t = p.get_thumb( href )
            thumb_html = "<a href=\"#{href}\"><img src=\"#{t}\" style=\"max-height:90px\"></a>"
            break
          end
        }
        if thumb_html
          ret << [ anchor , thumb_html]
        end
      end
      ret
    }
    
    if anchors_with_thumb.length == 0
      nil
    else
      thumb_area = @doc.createElement("div")
      thumb_area.setAttribute("class" , "thumb-area")
      thumb_box_pool = {}

      anchors_with_thumb.each{|anc , thumb_html|
        anc.setAttribute("class" , "has-thumb")
        uuid = java.util.UUID.randomUUID().toString()
        thumb_id = "thumb_"+uuid
        float_thumb_id = "float_thumb_"+uuid
        anc_id = "anc_"+uuid
        anc.setAttribute("id",anc_id) # ポジション検索のため
        
        thumb_box_is_created = false
        if thumb_box = thumb_box_pool[ thumb_html ]
          thumb_id = thumb_box.getAttribute("id")
        else
          thumb_box = @doc.createElement("span")
          thumb_box.setAttribute("class","thumb-box")
          thumb_box.setMember("innerHTML" , thumb_html )
          thumb_box.setAttribute("id" , thumb_id)
          thumb_box_is_created = true
          thumb_box_pool[ thumb_html ] = thumb_box
        end
        # もともとはanchorとimageで使い回すためにprocオブジェクトにしていた
        mouseover_proc = Proc.new{|ev|
          if not is_element_in_view( thumb_id )
            float_thumb_box = @doc.createElement("span")
            float_thumb_box.setAttribute("class","thumb-box thumb-over")
            float_thumb_box.setMember("innerHTML" , thumb_html )
            float_thumb_box.setAttribute("id" , float_thumb_id )

            a_top , a_left , a_width , a_height = element_offset( anc_id )
            b_top , b_left , b_width  ,b_height = element_offset( "top" )
            t_top , t_left , t_width , t_height = element_offset( thumb_id )
            p_top = a_top+a_height+4
            p_left = [ a_left , b_width - t_width ].min
            float_thumb_box.setAttribute("style","position:absolute; top:#{p_top}px; left:#{p_left}px; z-index:2")
            thumb_area.appendChild( float_thumb_box )
          end
          thumb_box.setAttribute("class", "thumb-box thumb-over")
          anc.setAttribute("class", "has-thumb thumb-over")
        }
        mouseout_proc = Proc.new{|ev|
          thumb_box.setAttribute("class", "thumb-box")
          anc.setAttribute("class", "has-thumb")
          remove( "##{float_thumb_id}")
        }
        set_event( anc ,       "mouseover" , false , &mouseover_proc )
        set_event( anc ,       "mouseout"  , false , &mouseout_proc )

        if thumb_box_is_created
          href = anc.getAttribute("href").to_s
          target_anchors = anchors.find_all{|a| a.getAttribute("href").to_s == href}

          mouseover_proc_thumb = Proc.new{|ev|
            # hrefで検索する
            target_anchors.each{|a| a.setAttribute("class", "has-thumb thumb-over") }
            thumb_box.setAttribute("class", "thumb-box thumb-over")
          }
          mouseout_proc_thumb = Proc.new{|ev|
            target_anchors.each{|a| a.setAttribute("class", "has-thumb") }
            thumb_box.setAttribute("class", "thumb-box")
          }
          set_event( thumb_box , "mouseover" , false , &mouseover_proc_thumb )
          set_event( thumb_box , "mouseout"  , false , &mouseout_proc_thumb )

          thumb_area.appendChild( thumb_box )
        end
      }
      thumb_area
    end
  end

  def user_history_comment_to_permalink( obj )
    link_id_without_kind = obj[:link_id].sub(/^t\d_/ , '')
    title_url = Util.title_to_url( html_decode(obj[:link_title].to_s) )
    "/r/#{obj[:subreddit]}/comments/#{link_id_without_kind}/#{title_url}/#{obj[:id]}"
  end

  def user_history_comment_to_post_url( obj )
    link_id_without_kind = obj[:link_id].sub(/^t\d_/ , '')
    title_url = Util.title_to_url( html_decode(obj[:link_title].to_s) )
    "/r/#{obj[:subreddit]}/comments/#{link_id_without_kind}/#{title_url}/"
  end

  def make_footer_element( mouseover_element , obj )
    comment_foot_outer = @doc.createElement("span")
    comment_foot_outer.setAttribute("class" , "comment-footer")
    #if mouseover_element
    #  comment_foot.setAttribute("style", "font-size:90%;")
    #end
    comment_foot = @doc.createElement("span")
    comment_foot_outer.appendChild( comment_foot ) # 将来footerに何か常時表示する場合に備えて入れ子にしてある
    
    parmalink_this = 
      if obj[:kind] == 't1'
        if @permalink
          @permalink + obj[:id]
        else
          user_history_comment_to_permalink( obj )
        end
      else
        @permalink || obj[:permalink]
      end

    comment_foot_open = @doc.createElement("a")
    if obj[:kind] == 't3'
      comment_foot_open.setTextContent("全体表示")
    else
      comment_foot_open.setTextContent("単独")
    end
    # partial comment pathを作れない問題
    comment_foot_open.setAttribute("href" , parmalink_this )

    comment_foot.appendChild( comment_foot_open )
    comment_foot.appendChild( @doc.createTextNode(" "))
    
    if obj[:parent_id] =~ /^t1/
      comment_foot_open_thread = @doc.createElement("a")
      comment_foot_open_thread.setTextContent("親")
      comment_foot_open_thread.setAttribute("href" , parmalink_this + "?context=8")
      comment_foot.appendChild( comment_foot_open_thread )
      comment_foot.appendChild( @doc.createTextNode(" "))

      ### ポップアップイベント
      parent_ct = "ct_" + obj[:parent_id]
      
      set_event( comment_foot_open_thread , 'mouseover' , true ){
        # 親コメントがページ内にあり、かつ画面外のときにポップアップ化
        $stderr.puts "親コメント用マウスオーバー"
        if parent = @doc.getElementById(parent_ct)
          if not is_element_in_view( parent_ct )
            parent_pop = @doc.createElement("div")
            t_top , t_left , t_width , t_height = element_offset( "ct_#{obj[:name]}" )
            p_top , p_left , p_width , p_height = element_offset(parent_ct)

            if t_top and p_top
              if t_top  < current_pos_center()
                parent_pop.setAttribute("style" , 
                                        "position:absolute; top:#{t_top+t_height+6}px; left:#{p_left}px;overflow:visible")
              else
                parent_pop.setAttribute("style" , 
                                        "position:absolute; top:#{t_top - p_height}px;left:#{p_left}px;overflow:visible")
              end
              
              parent_pop.setAttribute("class" , "popup-comment")
              parent_pop.setAttribute("id" , "pp_#{obj[:name]}")
              # parent_pop.setTextContent("ポップアップテスト")
              parent_pop.appendChild( parent.getChildNodes().item(0).cloneNode(true) );
              parent_pop.appendChild( parent.getChildNodes().item(1).cloneNode(true) );

              mouseover_element.appendChild( parent_pop )
            end
          else
            # ハイライト化
            $stderr.puts "親コメントは画面内にある"
            new_classes = parent.getAttribute("class").to_s + " comment-highlight"
            parent.setAttribute("class",new_classes)
          end
        end
      }
      set_event( comment_foot_open_thread , 'mouseout' , true ){
        $stderr.puts "親コメント用マウスアウト"
        remove( "#pp_#{obj[:name]}")
        if parent = @doc.getElementById(parent_ct)
          new_classes = parent.getAttribute("class").split(/ /).reject{|c| c == 'comment-highlight' }.join(" ")
          parent.setAttribute("class",new_classes)
        end
      }

    end
    
    if obj[:kind] == 't1' and @comment_post_list_mode
      comment_foot_full_comment = @doc.createElement("a")
      comment_foot_full_comment.setTextContent("全体")
      comment_foot_full_comment.setAttribute("href" , 
                                             user_history_comment_to_post_url(obj))
      comment_foot.appendChild( comment_foot_full_comment )
      comment_foot.appendChild( @doc.createTextNode(" "))
    end

    if obj[:kind] == 't1'
      comment_foot_open_ex = @doc.createElement("a")
      comment_foot_open_ex.setTextContent("外部ブラウザ")
      comment_foot_open_ex.setAttribute("href" , "#" )
      set_event( comment_foot_open_ex , 'click' , false ){
        url = @uh.linkpath_to_url( parmalink_this )
        Platform.runLater{
          App.i.open_external_browser( url )
        }
      }                           
      comment_foot.appendChild( comment_foot_open_ex )
      comment_foot.appendChild( @doc.createTextNode(" "))
    end
    
    ### 編集関係コマンド
    if not obj[:archived] and not is_deleted(obj)
      if is_repliable(obj) or is_editable(obj) or is_deletable(obj)
        space1 = @doc.createElement("span")
        space1.setAttribute("style" , "margin-right:0.5em;")
        comment_foot.appendChild( space1 )
      end

      if is_repliable(obj)
        comment_foot_reply = @doc.createElement("a")
        comment_foot_reply.setTextContent("返信")
        comment_foot_reply.setAttribute("href" , "#" )
        set_event( comment_foot_reply , 'click' , false ){
          # inboxable#reply(text) -> obj, message
          # submission#add_comment(text)
          # editable#edit(text) -> thing | submission と comment
          if @reply_cb
            Platform.runLater{ # js engineのcall stack溢れ対策
              @reply_cb.call( obj.dup )
            }
          end
        }
        comment_foot.appendChild( comment_foot_reply )
      end
      
      if is_editable(obj)
        # todo: submissionならselfかどうかもチェックする
        # if obj[:author] == @account_name
        comment_foot_edit = @doc.createElement("a")
        comment_foot_edit.setTextContent("編集")
        comment_foot_edit.setAttribute("href" , "#" )
        set_event( comment_foot_edit , 'click' , false ){
          if @edit_cb
            Platform.runLater{ # js engineのcall stack溢れ対策
              @edit_cb.call( obj.dup )
            }
          end
        }
        comment_foot.appendChild( @doc.createTextNode(" "))
        comment_foot.appendChild( comment_foot_edit )

      end

      if is_deletable(obj)
        ### 削除
        comment_foot_delete = @doc.createElement("a")
        comment_foot_delete.setTextContent("削除")
        comment_foot_delete.setAttribute("href" , "#" )
        set_event( comment_foot_delete , 'click' , false ){
          if @delete_cb
            Platform.runLater{ # js engineのcall stack溢れ対策
              ch = @e.executeScript("$(\"##{obj[:name]} .comment\").length")
              $stderr.puts "deleteコールバック呼び出し リプライ数:#{ch}"
              @delete_cb.call( obj.dup , (ch > 0) )
            }
          end
        }
        comment_foot.appendChild( @doc.createTextNode(" "))
        comment_foot.appendChild( comment_foot_delete )
      end

    end # archived?
    
    space2 = @doc.createElement("span")
    space2.setAttribute("style" , "margin-right:0.5em;")
    comment_foot.appendChild( space2 )

    #### その他メニュー
    comment_foot_others = @doc.createElement("a")
    comment_foot_others.setTextContent("▼")
    comment_foot_others.setAttribute("href","#")
    set_event( comment_foot_others , 'click' , false ){|ev|
      show_others_menu( obj , ev.getScreenX , ev.getScreenY )
    }
    comment_foot.appendChild( @doc.createTextNode(" "))
    comment_foot.appendChild( comment_foot_others )

    #### 投稿禁止状態の表示
    if obj[:archived]
      comment_foot_archived = @doc.createElement("span")
      comment_foot_archived.setTextContent("[アーカイブ済み]")
      comment_foot.appendChild( comment_foot_archived )
    end
    
    if @locked
      comment_foot_locked = @doc.createElement("span")
      comment_foot_locked.setTextContent("[ロックされたポスト]")
      comment_foot.appendChild( comment_foot_locked )
    end

    # event
    if( mouseover_element )
      comment_foot.setAttribute("style" , "visibility:hidden")
      
      set_event( mouseover_element , 'mouseover' , false ){
        comment_foot.setAttribute("style","visibility:visible")
      }
    
      set_event( mouseover_element, 'mouseout' , false ){
        comment_foot.setAttribute("style","visibility:hidden")
      }
    end
    
    comment_foot_outer
  end

  def is_comment_hidden?( name )
    ret = (@hard_ignored_item[ name ] or is_folded?( name ) )
    # $stderr.puts "#{name} is_comment_hidden? : #{ret}"
    ret
  end

  def show_others_menu( obj , x , y )
    @footer_others_menu_target = obj
    @footer_others_menu ||= create_footer_others_menu
    @footer_others_menu.show( @webview , x , y )
  end

  def create_footer_others_menu
    menu = ContextMenu.new
    items = []
    items << MenuItem.new("その他")
    items << SeparatorMenuItem.new
    items << save_item = CheckMenuItem.new("save")
    save_item.setOnAction{|ev|
      if @save_cb and @footer_others_menu_target
        @save_cb.call( @footer_others_menu_target , save_item.isSelected )
      end
    }
    items << hide_item = CheckMenuItem.new("hide")
    hide_item.setOnAction{|ev|
      if @hide_cb and @footer_others_menu_target
        @hide_cb.call( @footer_others_menu_target , hide_item.isSelected )
      end
    }

    menu.getItems.addAll( items )

    menu.setOnShowing{|ev|
      if @footer_others_menu_target and 
          @footer_others_menu_target[:kind] == 't3'
        hide_item.setVisible( true )
      else
        hide_item.setVisible( false )
      end

      save_item.setSelected( @footer_others_menu_target[:saved] )
      hide_item.setSelected( @footer_others_menu_target[:hidden] )
    }
    menu
  end

  # others_menuを消す
  def on_mouse_pressed(ev)
    super(ev)
    if not ev.isPopupTrigger
      if @footer_others_menu
        @footer_others_menu.hide
      end
    end
  end

  def set_user_info(obj)
    empty("#headline")
    headline = @doc.getElementById("headline")
    created = Time.at(obj[:created_utc].to_f).strftime("%Y-%m-%d %H:%M:%S")
    lc = Util.comma_separated_int( obj[:link_karma] )
    cc = Util.comma_separated_int( obj[:comment_karma] )
    html = <<EOF
<div class="userinfo">
<div>
<span class="userinfo-name">#{obj[:name]}</span>
<span class="userinfo-karma">リンクカルマ:#{lc} コメントカルマ:#{cc}</span>
</div>
<div>
<span class="userinfo-date">登録:#{created}</span>
</div>
</div>
EOF

    headline.setMember("innerHTML" , html )
  end

  def is_deletable(obj)
    (obj[:author] == @account_name) and (not is_deleted(obj)) and (not obj[:archived])
  end
  def is_repliable(obj)
    (not @locked) and (not obj[:locked] or @account_is_moderator) and
      @account_name and (not obj[:archived]) and (not @user_suspended ) and
      (not @comment_post_list_mode)
  end
  def is_editable(obj)
    obj[:author] == @account_name and ( obj[:kind] == 't1' or (obj[:is_self] and not @comment_post_list_mode)) and
      (not obj[:archived]) and (not @user_suspended)
  end
  def is_votable(obj)
    (not is_deleted(obj)) and @account_name and (not obj[:archived]) and (not @user_suspended)
  end

  def is_deleted( obj )
    # とりあえず
    # todo:コメント削除とアカウント削除を厳密に区別する方法がない
    # bodyがもともと[deleted]なら削除されたものと見做す
    
    # https://www.reddit.com/r/changelog/comments/3luvvy/reddit_change_making_removed_deleted_content_more/

    if obj[:kind] == 't3'
      if obj[:is_self]
        obj[:author] == "[deleted]" and (obj[:selftext] == '[deleted]' or obj[:selftext] == '[removed]')
      else
        obj[:author] == "[deleted]" and obj[:banned_by] # 自己削除は判定不能か
      end
    else
      obj[:author] == "[deleted]" and (obj[:body] == '[deleted]' or obj[:body] == '[removed]')
    end
  end

  def element_vote_score( element )
    
    downvote.getAttribute("src").to_s == @downvoted_img_url

  end

  def make_post_head_element( obj , subm = false )
    comm_head = @doc.createElement("span")
    if subm
      comm_head.setAttribute("class" , "subm-header")
    else
      comm_head.setAttribute("class" , "comment-header")
    end

    time_str = @doc.createElement("span")
    time_str.setAttribute("class" , "comment_time")
    time_str.setTextContent( Time.at( obj[:created_utc] ).strftime("%Y-%m-%d %H:%M:%S"))
    
    score = @doc.createElement("span")
    if obj[:score_hidden]
      score.setAttribute("class" , "score_hidden")
      score.setTextContent("[score hidden]")
    else
      score.setAttribute("class" , "score")
      score.setTextContent( obj[:score].to_s + "ポイント")
    end

    obj[:reddo_vote_score] = if obj[:likes] == true
                               1
                             elsif obj[:likes] == false
                               -1
                             else
                               0
                             end
    obj[:reddo_raw_score] = obj[:score].to_i - obj[:reddo_vote_score]
    author = make_user_element( obj )
    
    # vote arrows
    if is_votable(obj) # ↓でも分岐してる注意
      upvote = @doc.createElement("img")
      if obj[:likes] == true
        upvote.setAttribute("src" , @upvoted_img_url)
      else
        upvote.setAttribute("src" , @upvote_img_url)
      end
      upvote.setAttribute("class" , "upvote image_for_resize")
      
      downvote = @doc.createElement("img")
      if obj[:likes] == false
        downvote.setAttribute("src" , @downvoted_img_url)
      else
        downvote.setAttribute("src" , @downvote_img_url)
      end
      downvote.setAttribute("class" , "downvote image_for_resize")
      
      set_event(upvote , "click" , false){
        if upvote.getAttribute("src").to_s == @upvoted_img_url
          upvote.setAttribute("src" , @upvote_img_url)
          obj[:reddo_vote_score] = 0
          @vote_cb.call( obj , nil ) if @vote_cb
        else
          upvote.setAttribute("src" , @upvoted_img_url)
          downvote.setAttribute("src" , @downvote_img_url )
          obj[:reddo_vote_score] = 1
          @vote_cb.call( obj , true ) if @vote_cb
        end
        if not obj[:score_hidden]
          score.setTextContent( (obj[:reddo_raw_score] + obj[:reddo_vote_score]).to_s + "ポイント")
        end
      
      }
      set_event(downvote , "click" , false){
        if downvote.getAttribute("src").to_s == @downvoted_img_url
          downvote.setAttribute("src" , @downvote_img_url)
          obj[:reddo_vote_score] = 0
          @vote_cb.call( obj , nil ) if @vote_cb
        else
          downvote.setAttribute("src" , @downvoted_img_url)
          upvote.setAttribute("src" , @upvote_img_url)
          obj[:reddo_vote_score] = -1
          @vote_cb.call( obj , false ) if @vote_cb
        end
        if not obj[:score_hidden]
          score.setTextContent( (obj[:reddo_raw_score] + obj[:reddo_vote_score]).to_s + "ポイント")
        end
      }
    end # is_votable
    
    # ヘッダ部
    if obj[:kind] == 't1' or @comment_post_list_mode
      fold_switch = @doc.createElement('span')
      fold_switch.setAttribute("class","close-switch")
      fold_switch.setTextContent("[-]")
      set_event(fold_switch , 'click' , false ){
        ReadCommentDB.instance.set_closed( obj[:name] , true )
        comment_expand( obj[:name] , false )
      }
      comm_head.appendChild( fold_switch )
      comm_head.appendChild( @doc.createTextNode(" "))
    end      

    if obj[:reddo_new]
      new_mark = @doc.createElement("span")
      new_mark.setAttribute("class","new-mark")
      new_mark.setMember("innerHTML","NEW")
      comm_head.appendChild( new_mark )
      comm_head.appendChild( @doc.createTextNode(" "))
    end
    
    if obj[:stickied]
      sticky_mark = @doc.createElement("span")
      sticky_mark.setAttribute("class","sticky-mark")
      sticky_label_string = if obj[:kind] == 't3'
                              'Announcement'
                            else
                              'Sticky'
                            end
      sticky_mark.setMember("innerHTML",sticky_label_string)
      comm_head.appendChild( sticky_mark )
      comm_head.appendChild( @doc.createTextNode(" ") )
    end
    if obj[:locked]
      locked_mark = @doc.createElement("span")
      locked_mark.setAttribute("class","locked-mark")
      locked_mark.setMember("innerHTML","Locked")
      comm_head.appendChild( locked_mark )
      comm_head.appendChild( @doc.createTextNode(" ") )
    end

    comm_head.appendChild( score )
    if obj[:controversiality] and obj[:controversiality].to_i > 0
      dagger_mark = @doc.createElement("sup")
      dagger_mark.setAttribute("class" , "dagger")
      dagger_mark.setTextContent("†")
      comm_head.appendChild( dagger_mark )
    end

    if obj[:upvote_ratio] # submissionの場合
      percent = (obj[:upvote_ratio] * 100).to_i
      upvote_ratio = @doc.createElement("span")
      upvote_ratio.setAttribute("class","upvote_ratio")
      upvote_ratio.setMember("innerHTML","(#{percent}%)")
      comm_head.appendChild( upvote_ratio )
      comm_head.appendChild( @doc.createTextNode(" "))
    end

    comm_head.appendChild( @doc.createTextNode(" ") )
    if is_votable(obj)
      comm_head.appendChild( upvote )
      comm_head.appendChild( downvote )
    end

    if obj[:view_count]
      comm_head.appendChild( @doc.createTextNode(" ") )
      view_count = @doc.createElement("span")
      if obj[:view_count] == 1
        view_count.setTextContent("[1 view]")
      else
        view_count.setTextContent("[#{obj[:view_count]} views]")
      end
      comm_head.appendChild( view_count )
    end

    comm_head.appendChild( @doc.createTextNode(" ") )
    comm_head.appendChild( author )

    if obj[:gildings] and obj[:gildings][:gid_1].to_i > 0
      gs = obj[:gildings][:gid_1].to_i
      comm_head.appendChild( @doc.createTextNode(" ") )
      gilded_s = @doc.createElement("span")
      gilded_s.setAttribute("class","gilded-mark-s")
      gilded_num = if gs == 1
                     ""
                   else
                     gs.to_s
                   end
      gilded_s.setTextContent( "⚬" + gilded_num )
      comm_head.appendChild(gilded_s)
    end
    if obj[:gilded] and obj[:gilded].to_i > 0
      comm_head.appendChild( @doc.createTextNode(" ") )
      gilded = @doc.createElement("span")
      gilded.setAttribute("class","gilded-mark")
      gilded_num = if obj[:gilded] == 1
                     ""
                   else
                     obj[:gilded].to_s
                   end
      gilded.setTextContent( "★" + gilded_num )
      comm_head.appendChild(gilded)
    end
    if obj[:gildings] and obj[:gildings][:gid_3].to_i > 0
      gp = obj[:gildings][:gid_3].to_i
      comm_head.appendChild( @doc.createTextNode(" ") )
      gilded_p = @doc.createElement("span")
      gilded_p.setAttribute("class","gilded-mark-p")
      gilded_num = if gp == 1
                     ""
                   else
                     gp.to_s
                   end
      gilded_p.setTextContent( "★" + gilded_num )
      comm_head.appendChild(gilded_p)
    end

    comm_head.appendChild( @doc.createTextNode(" ") )
    comm_head.appendChild( time_str )

    # edited?
    if obj[:edited].is_a?( Float )
      edit_time = @doc.createElement("span")
      edit_time.setAttribute("class" , "comment_time")
      edit_time_str = Time.at( obj[:edited ] ).strftime("%Y-%m-%d %H:%M:%S")
      edit_time.setTextContent( "[編集 #{edit_time_str}]")
      
      comm_head.appendChild( @doc.createTextNode(" ") )
      comm_head.appendChild( edit_time )
    end

    # スパムフィルタ
    if obj[:banned_by] == true
      spam_filtered = @doc.createElement("span")
      spam_filtered.setAttribute("class" , "spam-filtered")
      spam_filtered.setTextContent( "スパムフィルタ")
      comm_head.appendChild( @doc.createTextNode(" ") )
      comm_head.appendChild( spam_filtered )
    end
    
    comm_head
  end

  def flair_richtext_to_html( richtext_ary )
    richtext_ary.map{|h|
      if h[:e] == 'text'
        html_decode( h[:t] )
      elsif h[:e] == 'emoji'
        "<img class=\"reddit-emoji\" src=\"#{h[:u]}\" alt=\"#{h[:a]}\" />"
      end
    }.join
  end
  
  def make_user_element( obj )
    author      = obj[:author]
    flair_text  = if obj[:author_flair_type] == "richtext"
                    flair_richtext_to_html( obj[:author_flair_richtext] )
                  else
                    html_decode(obj[:author_flair_text])
                  end
    
    flair_class = obj[:author_flair_css_class] # nilや""あり
    deleted = (author == '[deleted]')
    ex_style = case obj[:distinguished]
               when "admin"
                 " user-name-admin"
               when "moderator"
                 " user-name-mod"
               else
                 op = obj[:link_author] || @original_poster # :link_authorはuser履歴の場合のみある
                 if obj[:kind] == 't1' and (not deleted) and author == op
                   " user-name-op"
                 else
                   ""
                 end
               end

    user = @doc.createElement("span")
    user.setAttribute("class" , "user" )
    
    if deleted
      user_name = @doc.createElement("span")
      user_name.setTextContent( author )
    else
      user_name = @doc.createElement("a")
      user_name.setAttribute("class" , "user-name" + ex_style)
      user_name.setTextContent( author )
      user_name.setAttribute("href" , "/u/" + author )
    end
    
    user_flair = @doc.createElement("span")
    # user_flair.setTextContent( flair_text )
    if flair_text
      user_flair.setMember("innerHTML",flair_text)
    end
    flair_class2 = flair_class.to_s.split.map{|c| "flair-" + c }.join(" ").strip
    flair_class3 = if @use_user_flair_style and flair_class2.length > 0
                     "flair user-flair-styled " + flair_class2
                   else
                     "user-flair"
                   end
    user_flair.setAttribute("class" , flair_class3 )
    
    # 最近のflair background設定で上書く
    if flair_class3 == 'user-flair'
      style = ""
      if obj[:author_flair_background_color].to_s.length > 0
        style += "background-color: #{obj[:author_flair_background_color]};"

        # この色はreddoテーマに依存してはならない…
        if obj[:author_flair_text_color] == 'light'
          style += "color: #eeeeee; "
        elsif obj[:author_flair_text_color] == 'dark'
          style += "color: #222222; "
        end
        
      end
      user_flair.setAttribute("style" , style )
    end
    
    user.appendChild( user_name )
    user.appendChild( user_flair )
    
    user
  end
  
  # うまくいかない とりあえず cssでoverflow:hiddenにしておく
  def adjust_overflowing_user_flair()
#     @e.executeScript(<<EOF)
# $(".flair").each(function(i,e){
#   if( e.clientHeight < e.scrollHeight ){
#     e.setAttribute("style","vertical-align:baseline !important;");
#   }
# });
# EOF
  end

  def set_single_comment_highlight( name )
    selector = "#t1_#{name} > .comment-shown > .comment-this > .comment_text"
    # 旧:ffffc0
    @e.executeScript( <<EOF )
    var comm = $("#{selector}");
    if(comm)
      comm.css( "background-color" , "#{App.i.theme::COLOR::HTML_COMMENT_HIGHLIGHT}");
EOF
    
  end # end

  ### ハイライト
  def set_replying( name , mode:'reply' , move:true)
    if @replying
      clear_replying( @replying )
    end
    @replying = name

    selector = if name =~ /^t1/
                 # "##{name} > .comment-shown > .comment-this"
                 "#ct_#{name}"
               else
                 "#submission-command"
               end

    color = if mode == 'reply'
              App.i.theme::COLOR::HTML_COMMENT_REPLYING
            elsif mode == 'edit'
              App.i.theme::COLOR::HTML_COMMENT_EDITING
            end
    
    gradient = if name =~ /^t1/
                 "-webkit-linear-gradient(bottom, rgba(0,0,0,0) 0.5em, #{color})"
               else
                 "-webkit-linear-gradient(bottom, rgba(0,0,0,0), #{color})"
               end
    
    if @smooth_scroll
      move_script = <<EOF
    if(comm.hasClass("comment-this")){
      // scrollElementInView( comm );  // うまくいかない
      $('html,body').animate({
        scrollTop: comm.offset().top + 'px'
      });
    }
EOF
    else
      # comment画面が縮むのを待つ。てきとう
      move_script = <<EOF
    if(comm.hasClass("comment-this")){
        setTimeout( function(){
          $('html,body').scrollTop( comm.offset().top );
        },200);
    }
EOF
    end

    move_script_insert = if move
                           move_script
                         else
                           ""
                         end

    @e.executeScript( <<EOF )
    var comm = $("#{selector}");
    if(comm){
      // comm.css( "background-color" , "#{color}");
      comm.css( "background" , "#{gradient}");
      #{move_script_insert}
    }
EOF
    
  end
  
  def set_self_text_visible( visible )
    @self_text_visible = visible
    #if @doc
    #  if subm = @doc.getElementById("submission")
    #    disp = if visible
    #             "block"
    #           else
    #             "none"
    #           end
    #    subm.setAttribute("style" , "display:#{disp}")
    #  end
    #end
  end

  def set_comment_post_list_mode( mode )
    @comment_post_list_mode = mode
    if @doc
      vis = if mode
              "hidden"
            else
              "visible"
            end
      post = @doc.getElementById("post-area")
      post.setAttribute("style" , "visibility:#{vis}; height:0")
      
      #if users
      #  remove( "#post-area")
      #end
    end
  end
  attr_reader :comment_post_list_mode

  def clear_replying( name )
    
    selector = if name =~ /^t1/
                 # "##{name} > .comment-this"
                 "#ct_#{name}"
               else
                 "#submission-command"
               end
    
    @e.executeScript( <<EOF )
    var comm = $("#{selector}");
    if(comm){
      comm.css( "background-color" , "");
      comm.css( "background" , "");
    }
EOF
    @replying = nil
  end

  def get_current_screen_top_comment_id
    @e.executeScript(<<EOF)
(function(){
  var wtop = $(window).scrollTop();
  var comm_id = $("#post-area, .comment-this, .post-in-list").filter(function(i,e){
    return($(this).offset().top + $(this).height() > wtop );
  }).prop("id");
  if( typeof comm_id == 'undefined' )
    return null;
  else
    return comm_id;
})();
EOF
  end

  def set_message( html )
    if html
      me = @doc.getElementById("message")
      me.setMember("innerHTML",html)
    else
      empty("#message")
    end
  end

  JS_SCROLL_ELEMENT_IN_VIEW = <<EOF
function scrollElementInView( elem ){

    var wheight = $(window).height();

    var wtop = $(window).scrollTop();
    var wbot = wtop + wheight;
    var etop = elem.offset().top;
    var ebot = etop + elem.height();
    var is_large = wheight < elem.height();

    // window.cb.log("wtop:" + wtop + " wbot:" + wbot + " etop:" + etop + " ebot:" + ebot);

    var scrollTo = wtop;
    if( wtop < etop && ebot < wbot ){
      // 何もしない
    } else if( wbot < ebot ){
       if(is_large){
         scrollTo = etop;
       } else {
         scrollTo = etop - (wheight - elem.height());
       }
    } else if( etop < wtop ){
       if(is_large){
         scrollTo = ebot - wheight;
       } else {
         scrollTo = etop;
       }
    }
    // window.cb.log( "scrollTo=" + scrollTo );
    $('html,body').animate({
      scrollTop: scrollTo + 'px'
    });

}
EOF

  def base_html

html = <<EOF
<!DOCTYPE html>
<html >
<head>
<meta charset="UTF-8">
<link rel="stylesheet" type="text/css" href="file://#{CSS_PATH}">
<style>
#{style()}
</style>
<style id="additional-style">#{@additional_style}</style>
</head>
<body id="top">
<div id="message"></div>
<div id="headline"></div>
<div id="post-area">
<div id="preview-box"><img src="" id="preview" /></div>
<div id="title-area">
<span id="subm-head"></span><br>
<span id="link-flair"></span><a id="linked-title"></a> <span id="domain"></span> <span id="subreddit"></span>
<div id="crosspost-links"></div>
</div><!-- title-area -->
<div style="clear:both"></div>
<div id="submission"><div id="submission-switch-area"><span id="submission-switch"></span><span id="submission-switch-message"></span></div><div id="submission-text"></div></div>
<div id="submission-command"></div>
</div><!-- post area -->
<div id="comments"></div>
</body>
</html>
EOF

    html
  end

end
