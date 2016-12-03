
require 'java'
require 'jrubyfx'

require 'reddit_web_view_wrapper'

class PreviewWebViewWrapper < RedditWebViewWrapper
  
  def initialize( sjis_art:true , &cb )
    super(sjis_art:true , &cb)

  end
  attr_reader :webview

  def base_html()
    html = <<EOF
<!DOCTYPE html>
<html style="background-color:#{App.i.theme::COLOR::HTML_COMMENT_BG};">
<head>
<meta charset="UTF-8">
<style>
#{style()}
</style>
<style id="additional-style">#{@additional_style}</style>
</head>
<body>
<div class="md" id="sample">
</div>
</body>
</html>
EOF

    html
  end

  def dom_prepared(ov)
    super(ov)
    
    f= App.res("/res/snuownd.js").to_io
    @e.executeScript( f.read )
    f.close

    @e.executeScript("var mdParser = SnuOwnd.getParser();")
    
  end

  def set_md( md )
    #sample_area = @doc.getElementById("sample")
    #sample_area.setMember("innerHTML" , html)
    empty("#sample")
    text_wrapper = @doc.createElement("div")
    style_class = ""
    style_class += " use_link_style" if @use_link_style
    style_class += " use-sjis-art" if @sjis_art
    text_wrapper.setAttribute("class",style_class)
    
    text_wrapper2 = @doc.createElement("div")
    text_wrapper2.setAttribute("class","md")
    
    sample = @doc.getElementById("sample")
    sample.appendChild( text_wrapper )
    text_wrapper.appendChild( text_wrapper2 )

    @e.executeScript("mdParser").setMember("reddo_md" , md )
    @e.executeScript('$("#sample > div > div").html(mdParser.render(mdParser.reddo_md));')
  end

end
