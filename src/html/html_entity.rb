# -*- coding: utf-8 -*-

# htmlentities http://htmlentities.rubyforge.org/から引っこ抜いた
require 'html/html_entity_mapping' 

module Html_entity
  ENTITY_END = '(?:;|(?!\w))' # ?! 否定先読み
  def decode( string )
    string.to_s.gsub( /&(?:#(\d{1,7})|#x([0-9a-zA-Z]{1,6})|(\w+))#{ENTITY_END}/o){|w|
      m = Regexp.last_match
      if m[1]
        uc = [m[1].to_i].pack('U')
        if uc.respond_to?(:valid_encoding?) and not uc.valid_encoding?
          w
        else
          uc
        end
        
      elsif m[2]
        uc = [m[2].to_i(16)].pack('U')
        if uc.respond_to?(:valid_encoding?) and not uc.valid_encoding?
          w
        else
          uc
        end
        
      elsif m[3]
        if u = HTMLEntities::MAPPINGS['expanded'][m[3]]
          [u].pack('U')
        else
          w
        end
      else
        w
      end
    }
  end
  module_function :decode

end
