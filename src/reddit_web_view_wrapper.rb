# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'jruby/core_ext'
import 'javafx.concurrent.Worker'

import 'javafx.scene.web.WebView'

require 'web_view_wrapper'

class RedditWebViewWrapper < WebViewWrapper

  def initialize(sjis_art:true , &cb)
    super( sjis_art:sjis_art , &cb)
    @e.loadContent( base_html() )
  end
  attr_accessor :use_link_style

  def set_spoiler_open_event
    if @e
      @e.executeScript( <<EOF )
$(".md-spoiler-text").each(function(){
  $(this).click(function(){
    $(this).addClass("spoiler-open");
  });
});
EOF
    end
  end
  
  def enable_sjis_art( sjis )
    @sjis_art = sjis
    # ここで動的にclassを変えようとしても、うまくいかなかった
  end

  def reload_content
    @e.loadContent( base_html() )
  end

  CSS_PATH = Util.get_appdata_pathname + "webview/comment.css"
  
  def set_additional_style( style )
    @additional_style = style
    if @doc
      st = @doc.getElementById("additional-style")
      st.setMember("innerHTML",style)
    end
  end

  def base_html()
    html = <<EOF
<!DOCTYPE html>
<html >
<head>
<meta charset="UTF-8">
<style>
#{style}
</style>
<style id="additional-style">#{@additional_style}</style>
</head>
<body>
</body>
</html>
EOF

  end

  SJIS_ART_FONT = '"ＭＳ Ｐゴシック", "MS PGothic", "Mona", "mona-gothic-jisx0208.1990-0", "IPA モナー Pゴシック", "IPAMonaPGothic" , "Monapo" , "MeiryoKe_PGothic", "textar" , "ARISAKA-AA"'

  def style
    bold_style = if @artificial_bold
                   # "font-weight:normal; text-shadow: 1px 0px #222222;"
                   "font-weight:normal; text-shadow: 0.083333em 0px 0px currentColor; letter-spacing:+0.083333em;"
                 else
                   "font-weight:bold;"
                 end

    code_style = "font-size:16px; font-family:#{SJIS_ART_FONT};"

    base_font = if App.i.pref["fonts"].to_s.length > 0
                  "\"#{App.i.pref["fonts"]}\",sans-serif"
                else
                  '"DejaVu Sans",Tahoma,Arial,"Helvetica Neue","Lucida Grande",sans-serif'
                end

    line_height = App.i.pref["line_height"] || 140

    
    inline_oblique_style = if App.i.pref["artificial_oblique"]
                             "font-style:normal; display:inline-block; -webkit-transform:skew(-15deg);"
                           else
                             "font-style:oblique;"
                           end
    
    inline_oblique_style_inner = if App.i.pref["artificial_oblique"]
                                   "font-style:normal; display:inline;-webkit-transform:none;"
                                 else
                                   "font-style:oblique;"
                                 end

    underline_link = if App.i.pref["underline_link"]
                       ""
                     else
".md a {
  text-decoration:none;
}
.md a:hover{
  text-decoration:underline;
}"
                     end

    top_comment_margin = if App.i.pref["collapse_comment_margin"]
                           "margin: 0px 12px -1px 12px;"
                         else
                           "margin: 12px 12px 0px 12px;"
                         end

    comment_tree_line_image_url = App.res_url( App.i.theme::COMMENT_TREE_LINE)
    treeline_pos_calcstr = "#{0.5 * line_height / 100.0 }em + 0.9em + 12px" # なかなかぴったりいかない
    style = <<EOF
html {
  font-family:#{base_font};
  background-color:#{App.i.theme::COLOR::HTML_BG};
  color:#{App.i.theme::COLOR::HTML_TEXT};
}

button {
  color:#{App.i.theme::COLOR::HTML_TEXT};
  // font-size:95%; // 全体サイズに随うように
}

.highlight { background-color: #{App.i.theme::COLOR::HTML_TEXT_HIGHLIGHT_BG};}

.comment-highlight { background-color: #{App.i.theme::COLOR::HTML_COMMENT_HIGHLIGHT};}

a:link { color: #{App.i.theme::COLOR::HTML_LINK}; }

div.comment, div.post-in-list { 
  word-wrap:break-word;
  padding: 6px 6px 0px 6px;
  #{top_comment_margin}
  border-width: 1px 1px 1px 1px;
  border-style: solid;
  border-color: #{App.i.theme::COLOR::HTML_COMMENT_BORDER};
  background-color: #{App.i.theme::COLOR::HTML_COMMENT_BG};
}

div.post-in-list {
  /* border-style: dotted; */
  background-color: #{App.i.theme::COLOR::HTML_BG};
}

/* lv2 */
div.comment div.comment {
  /*
  border-width: 0px 0px 0px 5px ;
  border-style: solid none none solid;
  */

  /* background-imageによる実装 */
  border-width: 0 0 0 0 ;  

  background-image: url("#{comment_tree_line_image_url}"),  url("#{comment_tree_line_image_url}") ;
  background-size: 5px 100% , 15px 5px;
  background-position: top left , top calc(#{treeline_pos_calcstr}) left;
  background-repeat: no-repeat , no-repeat;

  margin: 0px 0px 0px 10px;
  padding: 0px 0px 0px 15px;
}

div.comment div.comment:last-of-type {
  background-size: 5px calc(#{treeline_pos_calcstr}), 15px 5px;
  background-position: top left , top calc(#{treeline_pos_calcstr}) left;
  background-repeat: no-repeat , no-repeat;
}
div.comment div.comment.tree_closed {
  background-size: 5px 100%, 15px 5px;
  background-position: top left , top 50% left;
}
div.comment div.comment:last-of-type.tree_closed {
  background-size: 5px 50%, 15px 5px;
  background-position: top left , top 50% left;
}

/* 縞々 */
/*
#comments > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment ,
#comments > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment ,
#comments > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment > .comment-shown > .comment ,
#comments > .comment > .comment-shown > .comment > .comment-shown > .comment {
    border-color: #{App.i.theme::COLOR::HTML_TEXT_THIN }
}
*/

/*
.comment-even-level {
  background-color: #dddddd;
}
*/

div.comment .md {
  margin:6px 0px 6px 0px;
  padding:0px 0px 0px 0px;
}

/* preview用 */
.md {
  word-wrap:break-word;
}

div.comment p {
  margin:0px 0px 0px 0px;
  padding:0px 0px 0px 0px;

}

.comment-this, .post-in-list-inner , .comment-hidden {
  padding:6px 6px 6px 6px;
}

.popup-comment {
  // background-color: #{App.i.theme::COLOR::HTML_BG};
  background-color: #{App.i.theme::COLOR::HTML_COMMENT_HIGHLIGHT};
  // border-color: #{App.i.theme::COLOR::HTML_COMMENT_BORDER};
  border-color:#{App.i.theme::COLOR::HTML_TEXT_THIN};
  border-style: solid;
  border-width: 1px 1px 1px 1px;
  padding: 4px 4px 4px 4px;
  margin: 4px 8px 4px 4px;
  z-index:2;
}

.comment-header , .user-history-comment-header , .comment-hidden {
  font-size:90%;
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
}

.subm-header {
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
}

.dagger {
  color: #{App.i.theme::COLOR::RED};
  font-family:sans-serif;
  #{bold_style}
}

.gilded-mark {
  color: #{App.i.theme::COLOR::STRONG_YELLOW};
  #{bold_style};
}
.gilded-mark-s {
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
  #{bold_style};
}
.gilded-mark-p {
  color: #{App.i.theme::COLOR::STRONG_BLUE};
  #{bold_style};
}

.comment-footer {
  padding:0px 3px 0px 3px;
  color:#{App.i.theme::COLOR::HTML_TEXT_THIN};
}

#comments > .comment .comment-this > .comment-footer {
  font-size:90%;
}

.comment .comment .comment-footer {
  font-size:90%;
}

.post-in-list-inner .comment-footer {
  font-size:90%;
}

.comment-footer a {
  text-decoration:none;
  padding:1px 3px 1px 3px;
  border-radius: 3px;
  background-color:#{App.i.theme::COLOR::HTML_COMMENT_FOOTER_LINK_BG};
  color:#{App.i.theme::COLOR::HTML_TEXT_THIN};
}

.comment-footer a:hover {
  background-color:#{App.i.theme::COLOR::HTML_COMMENT_FOOTER_LINK_HOVER_BG};
  color:#{App.i.theme::COLOR::HTML_COMMENT_BG};
}

.user-name, a.user-name {
  color: #{App.i.theme::COLOR::STRONG_BLUE};
  border-radius: 3px;
  text-decoration:none;
}

.user-name-admin, a.user-name-admin {
  color:#{App.i.theme::COLOR::HTML_COMMENT_BG};
  background-color: #{App.i.theme::COLOR::STRONG_RED}
}

.user-name-mod, a.user-name-mod {
  color:#{App.i.theme::COLOR::HTML_COMMENT_BG};
  background-color: #{App.i.theme::COLOR::STRONG_GREEN}
}

.user-name-op, a.user-name-op {
  color:#{App.i.theme::COLOR::HTML_COMMENT_BG};
  background-color: #{App.i.theme::COLOR::STRONG_BLUE}
}

.sticky-mark {
  color:#{App.i.theme::COLOR::HTML_COMMENT_BG};
  background-color: #{App.i.theme::COLOR::STRONG_GREEN};
  #{bold_style}
}

.upvote , .downvote , .dummy-arrow {
  height:16px;
  vertical-align: -2px;
}

.dummy-arrow {
  visibility:hidden;
}

.upvote:hover , .downvote:hover , .close-switch , #submission-switch {
  cursor: pointer;
  // font-family:monospace;
}

.user-flair {
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
  border-width: 1px;
  border-style: solid;
  border-color: #{App.i.theme::COLOR::HTML_COMMENT_BORDER};
  margin-left: 2px;
  display:inline;
}

.user-flair-styled {
  display:inline-block;
  margin-left: 4px !important;
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN} !important;
  background-color:rgba(0,0,0,0) !important;
  vertical-align:middle !important;
  overflow:hidden !important; // adjust_overflowing_user_flair()がうまくいかないので
}

.user-flair:empty {
  display:none;
}

.score {
#{bold_style}
}

strong,b {
#{bold_style}
}

em em, em i, i em, i i {
#{inline_oblique_style_inner}
}

em,i {
#{inline_oblique_style}
}

h1,h2,h3,h4,h5 { #{bold_style} }
.md h1, .md h3,.md h5 { #{bold_style} }
.md h2, .md h4 { font-weight:normal }
.md h6 { font-weight:normal; text-decoration:underline}

.md h1, .md h2{ font-size:1.2857142857142858em;line-height:1.3888888888888888em;margin-top:0.8333333333333334em;margin-bottom:0.8333333333333334em }
.md h3, .md h4{ font-size:1.1428571428571428em;line-height:1.25em;margin-top:0.625em;margin-bottom:0.625em}
.md h5, .md h6{ font-size:1em;line-height:1.4285714285714286em;margin-top:0.7142857142857143em;margin-bottom:0.35714285714285715em}

.use-sjis-art .md pre,
.use-sjis-art .md code,
.use-sjis-art #submission pre,
.use-sjis-art #submission code {
#{code_style}
line-height:100%;
}

.md { line-height:#{line_height}%; }

#preview-box {
  // display:inline-block;
  float:left;
  margin:5px;
  vertical-align:middle;
  text-align:center;
}

#preview {
  object-fit: contain;
}

.post-thumb-in-list {
  float:left;
  margin:5px;
  max-height:80px;
  max-width:240px;
  height:auto;
  width:auto;
}

#link-flair {
  color:#{App.i.theme::COLOR::HTML_BG};
  background-color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
  margin-right:2px;
  border-width: 1px;
  border-style: solid;
  border-color: #{App.i.theme::COLOR::HTML_COMMENT_BORDER};
  display:inline;
}

.spam-filtered {
  color:#{App.i.theme::COLOR::HTML_BG};
  background-color: #{App.i.theme::COLOR::STRONG_RED};
  margin-right:2px;
}

#link-flair:empty {
  display:none;
}

a#linked-title, a.link-title, a.title-subreddit-link {
  text-decoration:none;
}

a#linked-title:hover, a.link-title:hover, a.title-subreddit-link:hover {
  text-decoration:underline;
}

a#linked-title, .post-in-list-inner .link-title {
  font-size:110%;
  #{bold_style};
}

#{underline_link}

#title-area {
  margin: 8px;
}

#crosspost-links{
  margin-top: 0.6em;
  font-size:90%;
}
#crosspost-links:empty{
  display:none;
}

#submission {
  word-wrap:break-word;
  margin: 8px;
  padding: 7px;
  border-width: 2px;
  border-radius: 3px;
  border-style: solid;
  border-color: #{App.i.theme::COLOR::HTML_POST_BORDER};
  display:none; // 開始時
}

#submission-switch-area {
  margin-bottom:2px;
  font-size:90%;
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
}

#submission-command {
  margin: 8px;
  padding: 5px;
}

.md blockquote {
  border: 1px;
  border-style: dashed;
  margin: 6px;
  padding: 6px;
  // backrgound-color: #f8f8f8;

}

#submission p {
  margin-top: 0;
  margin-bottom: 0.4em;
}
.md p {
  margin-top: 0;
  margin-bottom: 0.4em !important;
}

.thumb-area {
  padding: 2px;
  background-color: #{App.i.theme::COLOR::HTML_THUMB_AREA_BG};
}

.thumb-box {
  padding: 4px;
  display:inline-block;
  max-height:98px;
}

.has-thumb {
  // やっぱりちょっとうるさい
  // background-color: #{App.i.theme::COLOR::HTML_THUMB_AREA_BG};
}

.thumb-over {
  background-color: #{App.i.theme::COLOR::RED}
}


table {
    border-collapse: collapse;
    margin-bottom:8px;
}

table, th, td {
    border: 1px solid #{App.i.theme::COLOR::HTML_TEXT_THIN};
    padding-left:6px;
    padding-right:6px;
}

.new-mark {
  // background-color: #{App.i.theme::COLOR::STRONG_YELLOW};
  // color:white;
  // padding:2px;
  // border-radius: 3px;

  color: #{App.i.theme::COLOR::STRONG_RED};
  #{bold_style};
}

.userinfo-name {
  font-size:120%;
  #{bold_style}
}

.userinfo-karma {
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
}

.userinfo-date {
  color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
}

.userinfo {
  margin:8px;
}

.md ol, .md ul{
  margin-bottom:0;
  margin-top:0;
}

.reddit-emoji {
  height: 0.95em;
}

.md-spoiler-text {
  border-radius: 0.2em;
  background-color:#{App.i.theme::COLOR::HTML_TEXT_THIN};
  color:#{App.i.theme::COLOR::HTML_TEXT_THIN};
  -webkit-animation-iteration-count: -1;
  cursor:pointer;
  
}

.md-spoiler-text.spoiler-open {
   -webkit-animation: spoiler-open 2s ease 0s 1 normal;
   -webkit-animation-fill-mode: forwards; /* stop at end */
   cursor:inherit;
}

.md-spoiler-text:hover {
   -webkit-animation: spoiler-open 2s ease 0s 1 normal;
   -webkit-animation-fill-mode: forwards; /* stop at end */
   cursor:pointer;
}

@-webkit-keyframes spoiler-open {
  0%   {
         color:  #{App.i.theme::COLOR::HTML_TEXT_THIN};
         background-color: #{App.i.theme::COLOR::HTML_TEXT_THIN};
        }
  100% {color:#{App.i.theme::COLOR::HTML_TEXT}; background-color: inherit;}
}

EOF

    return( super() + "\n" + style )
  end

end # class
