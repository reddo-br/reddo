# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'jruby/core_ext'
import 'javafx.concurrent.Worker'

import 'javafx.scene.web.WebView'

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
      on_mouse_pressed( ev )
    }
    @webview.setOnMouseReleased{|ev|
      on_mouse_released( ev )
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
      if is_inputting and App.i.is_printable_key_event( ev )
        ev.consume
      end
    }
    
    @smooth_scroll = App.i.pref['scroll_v2_smooth']
    @event_listeners = []
  end 
  attr_reader :webview
  
  def set_worker_running_cb( &cb )
    @worker_running_cb = cb
  end
  def set_worker_stop_cb( &cb)
    @worker_stop_cb = cb
  end
  
  def on_mouse_pressed( ev )
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
  end
  
  def on_mouse_released( ev )
    if ev.isPopupTrigger()
      # $stderr.puts "popup検出"
      Platform.runLater{ popup( ev.getScreenX , ev.getScreenY , ev.getX , ev.getY) }
      ev.consume
    end
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
      if @custom_menu
        @menu = @custom_menu # 後で消すために
        @menu.show( @webview , x , y )
        true
      else
        false
      end
    end
  end
  attr_accessor :custom_menu

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

    if App.i.pref["scroll_v2_enable"]
      @e.executeScript( scroll_script )
    end

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
        #cb = Proc.new{|ev|  link_clicked(ev,href) }
        #link.addEventListener( "click" , cb , false )
        set_event( link , 'click', false ){|ev|  link_clicked(ev,href) }
      end
    }
  end

  def link_clicked(ev,href) # module WevViewLinkHook
    # link = ev.getTarget().getAttribute("href")
    if @link_cb
      Platform.runLater{
        @link_cb.call( make_absolute_url(href) , ev.shiftKey)
      }
    end
    ev.preventDefault
  end
  
  # 明示的にイベントを削除するため,jrubyのラッパ生成を使わない ← 結局効果ない
  class RubyProcWrapper 
    include org.w3c.dom.events.EventListener
    def initialize
      @proc = Proc.new
    end

    java_signature 'void handleEvent(org.w3c.dom.events.Event)'
    def handleEvent(ev)
      @proc.call(ev)
    end
    become_java!
  end

  def set_event( element , evname , consume , free_explicitly:true)
    proc = Proc.new
    po = RubyProcWrapper.new{|ev| proc.call(ev) }
    @venet_listeners ||= []
    @event_listeners << [ element , evname , po ,consume] if free_explicitly
    element.addEventListener( evname , po , consume)
  end
  def clear_events
    @event_listeners.each{|e,name,po,co|
      e.removeEventListener( name,po,co )
      e.removeAttribute("reddo_hooked")
    }
    @event_listeners = []
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

    java_signature 'void log(java.lang.Object)'
    def log(obj)
      Platform.runLater{
        begin
          $stderr.puts( obj.to_s )
        rescue
          $stderr.puts $!
        end
      }
    end
    become_java!
  end

  CSS_PATH = Util.get_appdata_pathname + "webview/comment.css"
  # JS_PATH  = Util.get_appdata_pathname + "webview/jquery-2.1.4.min.js"
  
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

  def remove( selector )
    @e.executeScript("$(\"#{selector}\").empty().removeData().remove()")
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

  def scroll_to_id( element_id , animation:true)
    if animation
      @e.executeScript( <<EOF )
$('html,body').stop().animate({
  scrollTop:$('##{element_id}').offset().top
});
EOF
    else
      @e.executeScript( <<EOF )
$('html,body').stop().scrollTop( $('##{element_id}').offset().top );
EOF
    end    
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
  
  def scroll_to_id_center( id )
    if pos = id_to_pos(id)
      scroll_to_pos_center(pos)
    end
  end
  
  def id_to_pos( element_id )
    @e.executeScript( "if($('##{element_id}').length){$('##{element_id}').offset().top;}else{false;}" )
  end

  def current_pos()
    @e.executeScript( "document.body.scrollTop;" )
  end

  def current_pos_center()
    @e.executeScript( "document.body.scrollTop + window.innerHeight / 2" )
  end

  def page_height()
    @e.executeScript( "document.body.clientHeight" )
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
  
  def is_element_in_view( element_id )
    script = <<EOF
(function(){
  var elem = $('##{element_id}');
  var wheight = $(window).height();

  var wtop = $(window).scrollTop();
  var wbot = wtop + wheight;
  var etop = elem.offset().top;
  var ebot = etop + elem.height();
  return (wtop < etop) && (ebot < wbot);
})();
EOF
    @e.executeScript(script)
  end

  def element_offset( element_id )
    script = <<EOF
(function(){
  var elem = $('##{element_id}');
  return( elem.offset().top.toString() + ":" + elem.offset().left.toString() + ":" + elem.width().toString() + ":" + elem.height().toString() );
})();
EOF
    @e.executeScript(script).split(/:/).map{|c| c.to_i }
  end

#   def is_id_hidden?( element_id )
#     script = <<EOF
# var el = $('##{element_id}');
# if(el.length){
#   el.get(0).offsetParent == null;
# }else{
#   false;
# }
# EOF
#     @e.executeScript( script )
#   end

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
    ".highlight { background-color: #{App.i.theme::COLOR::STRONG_YELLOW};}"
  end

  def scroll_bottom
    @e.executeScript('$("html, body").scrollTop( $(document).height()-$(window).height())')
  end
  
  def scroll_top
    @e.executeScript('$("html, body").scrollTop(0)')
  end

  def screen_up(ratio = 1)
    if @smooth_scroll
      @e.executeScript("$(\"html, body\").clearQueue().finish().animate({scrollTop: document.body.scrollTop - $(window).height()*#{ratio} },300)")
    else
      @e.executeScript("$(\"html, body\").scrollTop( document.body.scrollTop - $(window).height()*#{ratio} )")
    end
  end

  def screen_down(ratio = 1)
    if @smooth_scroll
      @e.executeScript("$(\"html, body\").clearQueue().finish().animate({scrollTop: document.body.scrollTop + $(window).height()*#{ratio}},300)")
    else
      @e.executeScript("$(\"html, body\").scrollTop( document.body.scrollTop + $(window).height()*#{ratio} )")
    end
  end

  def get_scroll_pos_ratio
    @e.executeScript(<<EOF)
document.body.scrollTop / document.body.clientHeight
EOF
  end

  def set_scroll_pos_ratio(pos_ratio)
    @e.executeScript(<<EOF)
$("body").scrollTop( document.body.clientHeight * #{pos_ratio} )
EOF
  end

############# 加速度スクロール用スクリプト
  def scroll_script

    amount    = App.i.pref['scroll_v2_wheel_amount'] || 100
    accel_max = App.i.pref['scroll_v2_wheel_accel_max'] || 2.5
    
    # stopでjumptoendするとうまくいかない

    if @smooth_scroll
      scroll = <<EOF
  nowAnim = true;
  $("body").stop().animate({
      scrollTop: target_top_fixed
    }, duration , 'linear' , function(){ nowAnim = false});
EOF
    else
      scroll = <<EOF
  $("body").scrollTop( target_top_fixed );
EOF
    end

scr = <<EOF
var lastScrollTime;
var lastTargetPos = null;
var nowAnim = false;
var accel_max = #{accel_max};
document.onmousewheel = function(e){

  var dy = e.wheelDeltaY;
  
  var amount = #{amount};
  var accel = 1;
  var dt = 400;
  var eventTime;
  
  if(e.timeStamp == 0) // timeStampが取れない場合がある
    eventTime = (new Date()).getTime();
  else
    eventTime = e.timeStamp;
  
  if(lastScrollTime){
    dt = eventTime - lastScrollTime;

    // accel = 250000 / Math.pow(dt, 2);
    accel = 400 / dt;

    if(accel > accel_max)
      accel = accel_max;
    else if(accel < 1)
      accel = 1;

  }
  lastScrollTime = eventTime;
  amount *= accel;

  // window.cb.log( "accel:" + accel + " amount:" + amount); // ハンドラ内からは効かない…
  // $("body").append( "lastScrollTime:" + lastScrollTime + " dt:" + dt + " accel:" + accel + " amount:" + amount +"<br>");

  var cur_top = lastTargetPos || document.body.scrollTop;
  // var cur_top = document.body.scrollTop;

  if(dy > 0 )
    var target_top = cur_top - amount;
  else 
    var target_top = cur_top + amount;
  
  if( target_top < 0 )
    var target_top_fixed = 0;
  else if( target_top > (document.height - window.innerHeight))
    var target_top_fixed = document.height - window.innerHeight;
  else
    var target_top_fixed = target_top;

  var move_ratio = Math.abs(target_top_fixed - cur_top) / Math.abs(target_top - cur_top);
  var duration = 150 * move_ratio;
  
  lastTargetPos = target_top_fixed;

  #{scroll}

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
