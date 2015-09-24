# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'jruby/core_ext'
import 'javafx.concurrent.Worker'

import 'javafx.scene.web.WebView'

require 'web_view_wrapper'
require 'app_color'

class RedditWebViewWrapper < WebViewWrapper

  def initialize(sjis_art:true , &cb)
    super( sjis_art:true , &cb)
    @e.loadContent( base_html() )
  end

  CSS_PATH = Util.get_appdata_pathname + "webview/comment.css"
  
  def set_additional_style( style )
    st = @doc.getElementById("additional-style")
    st.setMember("innerHTML",style)
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
<style id="additional-style"></style>
</head>
<body>
</body>
</html>
EOF

  end

  SJIS_ART_FONT = '"ＭＳ Ｐゴシック", "MS PGothic", "Mona", "mona-gothic-jisx0208.1990-0", "IPA モナー Pゴシック", "IPAMonaPGothic" , "Monapo" , "MeiryoKe_PGothic", "textar" , "ARISAKA-AA"'

  def style
    bold_style = if @artificial_bold
                   "font-weight:normal; text-shadow: 1px 0px #222222;"
                 else
                   "font-weight:bold;"
                 end

    code_style = if @sjis_art
                   "font-size:16px; font-family:#{SJIS_ART_FONT};"
                 else
                   ""
                 end
    base_font = "\"#{App.i.pref["fonts"]}\",sans-serif" || '"DejaVu Sans",Tahoma,Arial,"Helvetica Neue","Lucida Grande",sans-serif'

    style = <<EOF
html {
  font-family:#{base_font};
}

div.comment { 
  word-wrap:break-word;
  padding: 6px 6px 0px 6px;
  margin: 12px 12px 0px 12px;
  border-width: 1px 1px 1px 1px;
  border-style: solid;
  border-color: #cccccc;
  background-color: #eeeeee;
}


div.comment > div.comment {
  border-width: 0px 0px 0px 5px ;
  border-style: solid none none solid;
  margin: 0px 0px 0px 10px;
  padding: 0px 0px 0px 0px;
}

.comment-even-level {
  background-color: #dddddd;
}

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

.comment_this {
  padding:6px 6px 6px 6px;

}

.comment_header {
  font-size:90%;
  color: #555555;
}

.subm_header {
  color: #444444;
}


.comment_footer {
  padding:0px 3px 0px 3px;
  color:#444444;
}

#comments > .comment > .comment_this > .comment_footer {
  font-size:90%;
}

.comment .comment .comment_footer {
  font-size:90%;
}

.comment_footer a {
  text-decoration:none;
  padding:1px 3px 1px 3px;
  border-radius: 3px;
  background-color:#cccccc;
  color:#444444;
}
.comment_footer a:hover {
  background-color: #004298;
  color:#eeeeee;
}

.user_name {
  color: #{AppColor::DARK_BLUE};
  border-radius: 3px;
  text-decoration:none;
}

.user_name_admin {
  color:white;
  background-color: #{AppColor::DARK_RED}
}

.user_name_mod {
  color:white;
  background-color: #{AppColor::DARK_GREEN}
}

.user_name_op {
  color:white;
  background-color: #{AppColor::DARK_BLUE}
}

.upvote , .downvote {
  height:16px;
  vertical-align: -2px;
}

.upvote:hover , .downvote:hover{
  cursor: pointer;
}

.user_flair {
  color: #333333;
  border-width: 1px;
  border-style: solid;
  border-color: #555555;
  margin-left: 2px;
}

.user_flair_styled {
  display:inline-block;
  // vertical-align: baseline !important; // webの値はだいたいうまくいかない
  margin-left: 4px;
  color:#333333 !important;
  background-color:rgba(0,0,0,0) !important;
}

.user_flair:empty {
  display:none;
}

.score {
#{bold_style}
}

strong,b {
#{bold_style}
}

h1,h2,h3,h4,h5 { #{bold_style} }

.md pre,
.md code,
#submission pre,
#submission code {
#{code_style}
}

#preview_box {
  // display:inline-block;
  float:left;
  margin:5px;
  vertical-align:middle;
  text-align:center;
}

#preview {
  object-fit: contain;
}

#link_flair {
  color:#dddddd;
  background-color: #222222;
  margin-right:2px;
}

#link_fliar:empty {
  display:none;
}

a#linked_title {
  font-size:110%;
  text-decoration:none;
  #{bold_style};
}

a#linked_title:hover {
  text-decoration:underline;
}

#title_area {
  margin: 8px;
}

#submission {
  word-wrap:break-word;
  margin: 8px;
  padding: 5px;
  border-width: 1px;
  border-radius: 3px;
  border-style: solid;
  border-color: #888888;
  display:none; // 開始時
}

/*
#submission:empty{
  display:none;
}
*/

#submission_command {
  margin: 8px;
  padding: 5px;
}

.md blockquote {
  border: 1px;
  border-style: dashed;
  margin: 6px;
  padding: 6px;
  backrgound-color: #f8f8f8;

}

.md p,
#submission p {
  margin-top: 0;
  margin-bottom: 0.5em;
}

.thumb_area {
  padding: 2px;
  background-color: #dddddd;
}

.thumb_box {
  padding: 4px;
  display:inline-block;
}

.thumb_over {
  background-color: #ce579b;
}

table {
    border-collapse: collapse;
}

table, th, td {
    border: 1px solid black;
}

.new_mark {
  // background-color: #{AppColor::DARK_YELLOW};
  // color:white;
  // padding:2px;
  // border-radius: 3px;

  color: #{AppColor::DARK_RED};
  #{bold_style};
}

EOF


    return style + "\n" + super()
  end

end # class
