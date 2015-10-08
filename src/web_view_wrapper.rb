# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'jruby/core_ext'
import 'javafx.concurrent.Worker'

import 'javafx.scene.web.WebView'

require 'app_color'
require 'html/html_entity'
require 'util'

import 'javafx.scene.control.MenuItem'
import 'javafx.scene.control.ContextMenu'
import 'javafx.geometry.Side'

require 'addressable/uri'

class WebViewWrapper

  def initialize(sjis_art:true , &cb)

    @dom_prepared_cb = cb
    @webview = WebView.new
    @webview.setOnMousePressed{|ev|
      if ev.isPopupTrigger() # プラットフォームにより、pressで来るときとreleaseで来るときがある
        # $stderr.puts "popup検出"
        Platform.runLater{ popup( ev.getScreenX , ev.getScreenY , ev.getX , ev.getY) }
        ev.consume
      else
        if @menu
          @menu.hide
          @menu = nil
        end
      end
    }
    @webview.setOnMouseReleased{|ev|
      if ev.isPopupTrigger()
        # $stderr.puts "popup検出"
        Platform.runLater{ popup( ev.getScreenX , ev.getScreenY , ev.getX , ev.getY) }
        ev.consume
      end
    }
    @webview.setContextMenuEnabled( false )
    @webview.setStyle("-fx-font-smoothing-type:gray")
    # base html
    @e = @webview.getEngine()
    @artificial_bold = App.i.pref["artificial_bold"]
    @sjis_art = sjis_art


    @e.load_worker.state_property.add_listener{ |ov , s ,t |
      if ov.getValue() == Worker::State::RUNNING
        @worker_running_cb.call if @worker_running_cb
      else
        if ov.getValue() == Worker::State::SUCCEEDED
          dom_prepared(ov)
        end
        @worker_stop_cb.call if @worker_stop_cb
      end
    }

    @e.setOnStatusChanged{|e|
      # $stderr.puts "status changed"
      App.i.status( e.getData() )
    }
    
    # @e.loadContent( base_html() )

    @webview.setOnKeyPressed{|ev|
      if is_inputting and ev.getText.to_s.length > 0 and ev.getText.ord >= 32
        ev.consume
      end
    }
    
  end 
  attr_reader :webview

  def set_worker_running_cb( &cb )
    @worker_running_cb = cb
  end
  def set_worker_stop_cb( &cb)
    @worker_stop_cb = cb
  end
  
  def popup( x , y , rx , ry)
    sel = get_selected_text.to_s
    href = get_href_text( rx , ry ).to_s
    
    if sel.length > 0
      item_copy = MenuItem.new("選択をコピー")
      item_copy.setOnAction{|ev|
        App.i.copy( sel )
      }
      item_search = MenuItem.new("選択をgoogle検索")
      item_search.setOnAction{|ev|
        url = Util.search_url( sel )
        Platform.runLater{
          App.i.open_external_browser( url )
        }
      }
      item_translate = MenuItem.new("選択をgoogle翻訳")
      item_translate.setOnAction{|ev|
        url = Util.translate_url( sel )
        Platform.runLater{
          App.i.open_external_browser( url )
        }
      }

      ###
      @menu = ContextMenu.new
      @menu.getItems.addAll( item_copy , item_search , item_translate)
      
      @menu.show( @webview , x , y )
      true

    elsif href.length > 0 and not href == "#"
      item_copy = MenuItem.new("リンクをコピー")
      item_copy.setOnAction{|ev|
        App.i.copy( make_absolute_url(href) )
      }

      @menu = ContextMenu.new
      @menu.getItems.addAll( item_copy )
      
      @menu.show( @webview , x , y )

      true
    else
      false
    end
  end

  def make_absolute_url( url )
    if @base_url
      begin
        url_o = Addressable::URI.parse( url.to_s )
        abs = @base_url.join( url_o )
        abs.to_s
      rescue
        url.to_s
      end
    else
      url.to_s
    end
  end

  def set_base_url( url )
    @base_url = Addressable::URI.parse( url.to_s )
  end

  def get_selected_text
    @e.executeScript("window.getSelection().toString()")
  end

  def get_href_text( x , y )
    if elem = @e.executeScript("document.elementFromPoint(#{x},#{y})")
      if href = elem.getAttribute("href")
        href.to_s
      else
        nil
      end
    else
      nil
    end
  end

  def dom_prepared( obs )
    @doc = @e.getDocument()
    
    window = @e.executeScript("window")
    window.setMember( "cb" , CommentCB.new(self))
    
    f = App.res("/res/jquery-2.1.4.min.js").to_io
    @e.executeScript( f.read )
    f.close
      
    f = App.res("/res/jquery.highlight-5.js").to_io
    @e.executeScript( f.read )
    f.close

    @e.executeScript( scroll_script )

    @dom_prepared_cb.call if @dom_prepared_cb
  end

  def set_link_cb
    @link_cb = Proc.new
  end

  # 外から内容を書きかえるたびに
  def set_link_hook()
    links = @doc.getElementsByTagName("a") # NodeListImpl
    0.upto( links.getLength() - 1){|n|
      link = links.item( n )
      if href = link.getAttribute("href") and 
          href !~ /^\#/ and 
          not link.getAttribute("reddo_hooked")
        link.setAttribute("reddo_hooked" , "true")
        cb = Proc.new{|ev|  link_clicked(ev,href) }
        link.addEventListener( "click" , cb , false )
      end
    }
  end

  def link_clicked(ev,href) # module WevViewLinkHook
    # link = ev.getTarget().getAttribute("href")
    if @link_cb
      Platform.runLater{
        @link_cb.call( make_absolute_url(href) )
      }
    end
    ev.preventDefault
  end
  
  # イベント付けやすいよう、引数の順序を変えただけ
  def set_event( element , evname , comsume )
    proc = Proc.new
    element.addEventListener( evname , proc , comsume)
  end
  
  def nl2a( nodelist )
    ret = []
    0.upto( nodelist.getLength() - 1){|n|
      ret << nodelist.item(n)
    }
    ret
  end

  # js内からjavaを呼ぶための
  class CommentCB
    def initialize(wvw)
      @wrapper = wvw
    end

    java_signature 'void log(java.lang.String)'
    def log(str)
      $stderr.puts str
    end
    become_java!
  end

  CSS_PATH = Util.get_appdata_pathname + "webview/comment.css"
  JS_PATH  = Util.get_appdata_pathname + "webview/jquery-2.1.4.min.js"
  
  # 廃止: 完了までの時間がわからない
  def html_decode_by_dom( enc_str )
    if enc_str
      @enc ||= @doc.createElement("div")
      @enc.setMember( "innerHTML" , enc_str )
      @enc.getTextContent()
    else
      nil
    end
  end

  def html_decode( enc_str )
    Html_entity.decode( enc_str )
  end

  def empty( selector )
    @e.executeScript("$(\"#{selector}\").empty()")
  end

  def html_encode( html_str )
    if html_str
      @enc ||= @doc.createElement("div")
      # @enc.setMember( "innerTEXT" , html_str )
      @enc.setTextContent( html_str )
      @enc.getMember( "innerHTML" )
    else
      nil
    end
  end
  
  def dump
    @e.executeScript('$("html").html()')
  end

  def scroll_to_id( element_id )
    @e.executeScript( <<EOF )
$('html,body').stop().animate({
  scrollTop:$('##{element_id}').offset().top
});
EOF
    
  end

  def scroll_to_pos( pos )
    @e.executeScript( <<EOF )
$('html,body').stop().animate({
  scrollTop:#{pos}
});
EOF
  end
  
  def scroll_to_pos_center( pos )
    @e.executeScript( <<EOF )
$('html,body').stop().animate({
  scrollTop:#{pos} - $(window).height() / 2
});
EOF
  end
  
  def id_to_pos( element_id )
    @e.executeScript( "$('##{element_id}').offset().top" )
  end

  def current_pos()
    @e.executeScript( "document.body.scrollTop;" )
  end

  def current_pos_center()
    @e.executeScript( "document.body.scrollTop + window.innerHeight / 2" )
  end

  def highlight( word )
    if word.to_s.length > 0
      @e.executeScript( "$('body').removeHighlight().highlight('#{word}');" )
    else
      @e.executeScript( "$('body').removeHighlight();")
    end
  end

  def current_highlight_poses
    jsobj = @e.executeScript( <<EOF )
$(".highlight").map( function(){
  return $(this).offset().top;
}).get();
EOF
    ret = []
    0.upto( jsobj.getMember("length") - 1){|n|
      ret << jsobj.getMember( n.to_s )
    }
    ret
  end

  def scroll_to_highlight( forward )
    hl_poses =current_highlight_poses
    scroll_to_next_position( forward , hl_poses )
  end

  def scroll_to_next_position( forward , poses )
    # start_pos = current_pos
    start_pos = current_pos_center
    target = nil

    if is_scroll_bottom and forward
      $stderr.puts "scroll_to_next_position: 先頭から再開"
      start_pos = 0
    elsif is_scroll_top and not forward
      start_pos = poses.last + 1
    end

    $stderr.puts "scroll_to_next_position"
    if poses.length > 0
      
      if forward
        target = poses.bsearch{|e| e > start_pos + 1}
        target ||= poses[0]
      else
        target = poses.reverse.bsearch{|e| e < start_pos - 1}
        target ||= poses[-1]
      end

      # scroll_to_pos( target )
      scroll_to_pos_center( target )
      
    end # length > 0

  end

  def is_inputting
    @e.executeScript('$(document.activeElement).is(":input")')
  end

  def is_scroll_bottom
    @e.executeScript('$(window).scrollTop() + $(window).height() == $(document).height()')
  end
  def is_scroll_top
    @e.executeScript('$(window).scrollTop() == 0')
  end

  def style
    ".highlight { background-color: #{AppColor::DARK_YELLOW};}"
  end

  def scroll_bottom
    @e.executeScript('$("html, body").scrollTop( $(document).height()-$(window).height())')
  end
  
  def scroll_top
    @e.executeScript('$("html, body").scrollTop(0)')
  end

  def screen_up(ratio = 1)
    @e.executeScript("$(\"html, body\").clearQueue().finish().animate({scrollTop: document.body.scrollTop - $(window).height()*#{ratio} },300)")
  end

  def screen_down(ratio = 1)
    @e.executeScript("$(\"html, body\").clearQueue().finish().animate({scrollTop: document.body.scrollTop + $(window).height()*#{ratio}},300)")
  end

############# 加速度スクロール用スクリプト
  def scroll_script

    accel_max = App.i.pref['wheel_accel_max'] || 2.5
    
scr = <<EOF
var lastScrollTime;
var lastTargetPos = null;
var nowAnim = false;
var accel_max = #{accel_max};
window.onmousewheel = function(e){
  var dy = e.wheelDeltaY
  // window.cb.log(dy.toString()); // 上4800 下-4800
  
  var amount = 100;
  var accel = 1;
  var log_1000 = Math.log(1000);
  var dt = 1000;
  if(lastScrollTime){
    dt = e.timeStamp - lastScrollTime;
    // window.cb.log( "dt=" + dt.toString());

    /* 
    var log_dms = Math.min( Math.log( dt + 1) , log_1000);
    accel = log_1000 / log_dms
    */

    accel = 500 / dt;

    if(accel > accel_max)
      accel = accel_max;
    if(accel < 1)
      accel = 1;

  }
  lastScrollTime = e.timeStamp;

  amount *= accel;

  // window.cb.log( "amount=" + amount.toString());

  var top = lastTargetPos || document.body.scrollTop;
  // var top = $("body").scrollTop();

  if(dy > 0 )
    top -= amount;
  else 
    top += amount;
  
  if( top < 0 )
    top = 0;
    
  // window.cb.log( "document.height=" + document.height.toString());
  // window.cb.log( "window.height="   + window.innerHeight.toString());

  if( top > document.height - window.innerHeight)
    top = document.height - window.innerHeight;

  // window.cb.log( "top=" + top.toString());
  lastTargetPos = top;
  // document.body.scrollTop = top;

  nowAnim = true;
  $("body").stop().animate({
    scrollTop: top
  }, 300 , 'swing' , function(){ nowAnim = false});

  e.preventDefault();
};

// wheel以外のスクロールでlastを解除
window.onscroll = function(){
  if( !nowAnim )
    lastTargetPos = document.body.scrollTop;
}

EOF
    scr
  end

end # class
