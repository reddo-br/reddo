# -*- coding: utf-8 -*-

# htmlentities http://htmlentities.rubyforge.org/から引っこ抜いた
# require 'html/html_entity_mapping' 
import 'org.apache.commons.lang3.StringEscapeUtils'
module Html_entity
  def decode(str)
    # apache commonsでおきかえ
    StringEscapeUtils.unescapeHtml4( str )
  end
  module_function :decode

end
