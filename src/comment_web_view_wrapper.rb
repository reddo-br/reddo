# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'
require 'reddit_web_view_wrapper'
require 'html/html_entity'

class CommentWebViewWrapper < RedditWebViewWrapper

  def initialize(sjis_art:true , &dom_prepared_cb)
    super(sjis_art:sjis_art , &dom_prepared_cb)

    @upvote_img_url   = App.res_url( "/res/upvote.png")
    @downvote_img_url = App.res_url( "/res/downvote.png")
    @upvoted_img_url   = App.res_url( App.i.theme::HTML_UPVOTED)
    @downvoted_img_url = App.res_url( App.i.theme::HTML_DOWNVOTED)

    $stderr.puts "internal url upvote #{@upvote_img_url}"

    @self_text_visible = true
  end
  attr_reader :webview

  def dom_prepared(ov)
    super(ov)
    @div_submission = @doc.getElementById("submission")
    @div_comments   = @doc.getElementById("comments")
    
    # @e.executeScript( JS_SCROLL_ELEMENT_IN_VIEW )
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

  def set_account_name( name )
    @account_name = name
  end

  def set_user_suspended( suspended )
    @user_suspended = suspended
  end

  def set_url_handler( uh )
    @uh = uh
  end

  def set_title(title , link = nil , selftext = false)
    dom_title = @doc.getElementById("linked_title")
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
    subreddit_info.appendChild( @doc.createTextNode("["))
    subreddit_info.appendChild( subreddit_link )
    subreddit_info.appendChild( @doc.createTextNode("]"))

    subm = @doc.getElementById("submission")
    if obj[:is_self] and @self_text_visible and obj[:selftext_html].to_s.length > 0
      # $stderr.puts "*** selfテキスト表示"
      # $stderr.puts obj[:selftext_html]
      subm.setAttribute("style","display:block")
      subm.setMember( "innerHTML" , html_decode( obj[:selftext_html].to_s ))
    else
      subm.setAttribute( "style","display:none")
      # subm.setMember("innerHTML" , "") # :empty -> display:none
    end

    if thumb = make_thumbnail_element( subm )
      subm.appendChild( thumb )
    end

    subm_head = make_post_head_element( obj , true )
    
    sh = @doc.getElementById("subm_head")
    empty("#subm_head")
    # sh.setMember("innerHTML" , "" )
    sh.appendChild( subm_head )

    flair = @doc.getElementById("link_flair")
    flair.setMember("innerHTML" , html_decode(obj[:link_flair_text].to_s))

    img = @doc.getElementById("preview")
    imgb = @doc.getElementById("preview_box")

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
    command = @doc.getElementById("submission_command")
    # command.setMember("innerHTML" , "" )
    empty("#submission_command")
    command.appendChild( foot )
  end

  def find_first_child( comment_node )
    children = comment_node.getChildNodes()
    ret = nil
    (0).upto( children.getLength() - 1 ){|n|
      node = children.item(n)
      if node.getAttribute("id") !~ /^ct_/
        ret = node
        break
      end
    }
    return ret
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
    
    parent = @doc.getElementById(parent) if parent.is_a?(String)

    if not parent or obj.is_a?(Redd::Objects::MoreComments) # moreは階層の中に入ってないこともある
      if obj.kind_of?(Hash)
        parent_id = obj[:parent_id]
        if parent_id =~ /^t3/
          parent = @doc.getElementById("comments")
        else
          parent = @doc.getElementById( parent_id )
        end
        # 部分コメント用 いちおうトップにしておく
        parent ||= @doc.getElementById("comments")
      else # MoreCommentなど
        parent_id = obj.parent_id
        if parent_id =~ /^t3/
          parent = @doc.getElementById("comments")
        else
          parent = @doc.getElementById(parent_id) # moreは階層の中に入ってないこともある
        end
      end
    end

    if parent
      # if obj.kind_of?(Array)
      if obj.is_a?( Redd::Objects::MoreComments )
        if obj.count > 0

          more , more_button , elem_id = create_more_element( "もっと見る(#{obj.count})" )

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
          comment = old_comment_this.parentNode()
          comment.replaceChild( comment_this, old_comment_this )
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
          comment.appendChild( comment_this )
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
              add_comment( cc , comment , recursive:recursive , prepend:prepend )
            }
          end
        end
      end
    end

  end # add_comment

  def add_list_more_button
    comments = @doc.getElementById("comments")

    more , more_button , elem_id = create_more_element

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

    [ more , more_button , elem_id ]
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

    # @div_comments.setMember("innerHTML" , "")
    # @div_submission.setMember("innerHTML","")
    empty("#submission")
    empty("#comments")
    
    #if t = @doc.getElementById("linked_title")
    #  t.setMember("innerHTML" , "")
    #end
    empty("#linked_title")
    empty("#domain")
    empty("#subreddit")
    # todo: submissionも複数に対応する
    # @doc.getElementById("subm_head").setMember("innerHTML","")
    if pv = @doc.getElementById("preview")
      pv.setAttribute("src","")
    end
    # @doc.getElementById("link_flair").setMember("innerHTML","")
    # @doc.getElementById("submission_command").setMember("innerHTML","")

    empty("#subm_head")
    empty("#link_flair")
    empty("#submission_command")

  end

  def make_comment_this_element( obj )
    #comment = @doc.createElement("div")
    #comment.setAttribute("id" , obj[:name])
    #comment.setAttribute("class" , "comment")

    comment_this = @doc.createElement( "div")
    comment_this.setAttribute("class" , "comment_this")
    comment_this.setAttribute("id" , "ct_" + obj[:name].to_s )
    
    if @comment_post_list_mode
      link_area = @doc.createElement("div")
      link_area.setAttribute("class","user_history_comment_header")
      post_link = @doc.createElement("a")
      post_link.setAttribute("href" , html_decode(obj[:link_url]))
      post_link.setMember("innerHTML", html_decode(obj[:link_title]))
      post_link.setAttribute("class" , "link-title")

      link_area.appendChild( post_link )

      link_area.appendChild( @doc.createTextNode(" ["))
      
      sub_link = @doc.createElement("a")
      sub_link.setMember("innerHTML" , obj[:subreddit].to_s )
      sub_link.setAttribute("href" , @uh.subname_to_url( obj[:subreddit]).to_s )
      link_area.appendChild( sub_link )
      
      link_area.appendChild( @doc.createTextNode("]"))

      comment_this.appendChild( link_area )
    end

    comm_head = make_post_head_element( obj )
    comment_this.appendChild( comm_head )

    comment_text = @doc.createElement("div")
    comment_text.setAttribute("class" , "comment_text")
    comment_text.setMember("innerHTML" , html_decode(obj[:body_html].strip) )
    
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

    if thumb_url = Util.decoded_thumbnail_url( obj )
      thumb = @doc.createElement("img")
      thumb.setAttribute("class","post-thumb-in-list")
      thumb.setAttribute("src" , thumb_url )
      post_title.appendChild( thumb )
    end

    post_title.appendChild( make_link_title_in_list(obj))
    post.appendChild( post_title )
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
    
    linked_title_area.appendChild( @doc.createTextNode(" ["))
    linked_title_area.appendChild( subreddit_link )
    linked_title_area.appendChild( @doc.createTextNode("]"))

    linked_title_area
  end

  def make_thumbnail_element( elem )
    anchors = nl2a(elem.getElementsByTagName("a"))
    anchors_with_thumb = anchors.inject([]){|ret,anchor| 
      href = anchor.getAttribute("href").to_s
      if href.length > 0
        thumb_html = nil
        $thumbnail_plugins.each{|p|
          if t = p.get_thumb( href )
            thumb_html = t
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
      thumb_area.setAttribute("class" , "thumb_area")
      
      anchors_with_thumb.each{|anc , thumb_html|
        thumb_box = @doc.createElement("span")
        thumb_box.setAttribute("class","thumb_box")
        thumb_box.setMember("innerHTML" , thumb_html )
        mouseover_proc = Proc.new{|ev|
          thumb_box.setAttribute("class", "thumb_box thumb_over")
          anc.setAttribute("class", "thumb_over")
        }
        mouseout_proc = Proc.new{|ev|
          thumb_box.setAttribute("class", "thumb_box")
          anc.setAttribute("class", "")
        }
        #thumb_box.addEventListener( "mouseover" , mouseover_proc , false )
        #anc.addEventListener( "mouseover" , mouseover_proc , false )
        #thumb_box.addEventListener( "mouseout" , mouseout_proc , false )
        #anc.addEventListener( "mouseout" , mouseout_proc , false )

        set_event( thumb_box , "mouseover" , false , &mouseover_proc )
        set_event( anc ,       "mouseover" , false , &mouseover_proc )
        set_event( thumb_box , "mouseout"  , false , &mouseout_proc )
        set_event( anc ,       "mouseout"  , false , &mouseout_proc )

        thumb_area.appendChild( thumb_box )
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
    comment_foot = @doc.createElement("span")
    comment_foot.setAttribute("class" , "comment_footer")
    #if mouseover_element
    #  comment_foot.setAttribute("style", "font-size:90%;")
    #end

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
    
    space1 = @doc.createElement("span")
    space1.setAttribute("style" , "margin-right:0.5em;")
    comment_foot.appendChild( space1 )
    
    if obj[:archived]
      comment_foot_archived = @doc.createElement("span")
      comment_foot_archived.setTextContent("[アーカイブ済み]")
      comment_foot.appendChild( comment_foot_archived )
    elsif is_deleted( obj )
      #
    else
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

      if @locked
        comment_foot_locked = @doc.createElement("span")
        comment_foot_locked.setTextContent("[ロックされたポスト]")
        comment_foot.appendChild( comment_foot_locked )
      end

    end # archived?

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
    
    comment_foot
  end

  def set_user_info(obj)
    empty("#headline")
    headline = @doc.getElementById("headline")
    created = Time.at(obj[:created_utc].to_f).strftime("%Y-%m-%d %H:%M:%S")
    html = <<EOF
<div class="userinfo">
<div>
<span class="userinfo_name">#{obj[:name]}</span>
<span class="userinfo_karma">リンクカルマ:#{obj[:link_karma]} コメントカルマ:#{obj[:comment_karma]}</span>
</div>
<div>
<span class="userinfo_date">登録:#{created}</span>
</div>
</div>
EOF

    headline.setMember("innerHTML" , html )
  end

  def is_deletable(obj)
    (obj[:author] == @account_name) and (not is_deleted(obj)) and (not obj[:archived])
  end
  def is_repliable(obj)
    (not @locked) and @account_name and (not obj[:archived]) and (not @user_suspended ) and
      (not @comment_post_list_mode)
  end
  def is_editable(obj)
    obj[:author] == @account_name and ( obj[:kind] == 't1' or obj[:is_self] ) and
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
      comm_head.setAttribute("class" , "subm_header")
    else
      comm_head.setAttribute("class" , "comment_header")
    end

    time_str = @doc.createElement("span")
    time_str.setAttribute("class" , "comment_time")
    time_str.setTextContent( Time.at( obj[:created_utc] ).strftime("%Y-%m-%d %H:%M:%S"))
    
    score = @doc.createElement("span")
    score.setAttribute("class" , "score")
    score.setTextContent( obj[:score].to_s + "ポイント")

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
      upvote.setAttribute("class" , "upvote")
      
      downvote = @doc.createElement("img")
      if obj[:likes] == false
        downvote.setAttribute("src" , @downvoted_img_url)
      else
        downvote.setAttribute("src" , @downvote_img_url)
      end
      downvote.setAttribute("class" , "downvote")
      
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
        score.setTextContent( (obj[:reddo_raw_score] + obj[:reddo_vote_score]).to_s + "ポイント")
      
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
        score.setTextContent( (obj[:reddo_raw_score] + obj[:reddo_vote_score]).to_s + "ポイント")
      }
    end # is_votable
    
    # ヘッダ部

    if obj[:reddo_new]
      new_mark = @doc.createElement("span")
      new_mark.setAttribute("class","new_mark")
      new_mark.setMember("innerHTML","NEW")
      comm_head.appendChild( new_mark )
      comm_head.appendChild( @doc.createTextNode(" "))
    end
    
    if obj[:stickied]
      sticky_mark = @doc.createElement("span")
      sticky_mark.setAttribute("class","sticky_mark")
      sticky_mark.setMember("innerHTML","sticky")
      comm_head.appendChild( sticky_mark )
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

    comm_head.appendChild( @doc.createTextNode(" ") )
    comm_head.appendChild( author )

    if obj[:gilded] and obj[:gilded].to_i > 0
      comm_head.appendChild( @doc.createTextNode(" ") )
      gilded = @doc.createElement("span")
      gilded.setAttribute("class","gilded_mark")
      gilded_num = if obj[:gilded] == 1
                     ""
                   else
                     obj[:gilded].to_s
                   end
      gilded.setTextContent( "★" + gilded_num )
      comm_head.appendChild(gilded)
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

    comm_head
  end

  def make_user_element( obj )
    author      = obj[:author]
    flair_text  = obj[:author_flair_text]
    flair_class = obj[:author_flair_css_class] # nilや""あり
    deleted = (author == '[deleted]')
    ex_style = case obj[:distinguished]
               when "admin"
                 " user_name_admin"
               when "moderator"
                 " user_name_mod"
               else
                 op = obj[:link_author] || @original_poster # :link_authorはuser履歴の場合のみある
                 if obj[:kind] == 't1' and (not deleted) and author == op
                   " user_name_op"
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
      user_name.setAttribute("class" , "user_name" + ex_style)
      user_name.setTextContent( author )
      user_name.setAttribute("href" , "/u/" + author )
    end
    
    user_flair = @doc.createElement("span")
    user_flair.setTextContent( flair_text )
    flair_class2 = flair_class.to_s.split.map{|c| "flair-" + c }.join(" ").strip
    flair_class3 = if flair_class2.length > 0
                     "user_flair_styled flair " + flair_class2
                   else
                     "user_flair"
                   end
    user_flair.setAttribute("class" , flair_class3 )

    user.appendChild( user_name )
    user.appendChild( user_flair )
    
    user
  end
  
  def set_single_comment_highlight( name )
    selector = "#t1_#{name} > .comment_this > .comment_text"
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
                 "##{name} > .comment_this"
               else
                 "#submission_command"
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
    if(comm.hasClass("comment_this")){
      // scrollElementInView( comm );  // うまくいかない
      $('html,body').animate({
        scrollTop: comm.offset().top + 'px'
      });
    }
EOF
    else
      # comment画面が縮むのを待つ。てきとう
      move_script = <<EOF
    if(comm.hasClass("comment_this")){
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
      post = @doc.getElementById("post_area")
      post.setAttribute("style" , "visibility:#{vis}; height:0")
      
      #if users
      #  remove( "#post_area")
      #end
    end
  end

  def clear_replying( name )
    
    selector = if name =~ /^t1/
                 "##{name} > .comment_this"
               else
                 "#submission_command"
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
    var wbot = wtop + wheight
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
<!--<link rel="stylesheet" type="text/css" href="file://#{CSS_PATH}">-->
<style>
#{style()}
</style>
<style id="additional-style">#{@additional_style}</style>
</head>
<body id="top">
<div id="message"></div>
<div id="headline"></div>
<div id="post_area">
<div id="preview_box"><img src="" id="preview" /></div>
<div id="title_area">
<span id="subm_head"></span><br>
<span id="link_flair"></span><a id="linked_title"></a> <span id="domain"></span> <span id="subreddit"></span>
</div><!-- title_area -->
<div style="clear:both"></div>
<div id="submission"></div>
<div id="submission_command"></div>
</div><!-- post area -->
<div id="comments"></div>
</body>
</html>
EOF

    html
  end

end
