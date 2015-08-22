
require 'util'
require 'pref/prefbase'

class Session < Prefbase

  def initialize
    @file = Util.get_appdata_pathname + "session.json"
    super( @file )
  end

  def set_page_infos( infos )
    self['page_infos'] = infos
  end

  def get_page_infos
    pi = self['page_infos']
    pi.to_a.map{|h| hash_key_string_to_sym(h) }
  end

  def hash_key_string_to_sym(h)
    h2 = {}
    h.each{|k,v|
      if k.is_a?(String)
        h2[ k.to_sym ] = v
      else
        h2[ k ] = v
      end
    }
    h2
  end

end

