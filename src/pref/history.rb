
require 'util'
require 'pref/prefbase'

class History < Prefbase

  def initialize
    @file = Util.get_appdata_pathname + "history.json"
    super( @file )
  end

  def set_history( history )
    self['history_array'] = history
  end

  def get_history
    hi = self['history_array'] || []
    hi.to_a.map{|info,name| 
      [hash_key_string_to_sym(info) , name]
    }
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

  HISTORY_MAX = 20
  def add( info , name )
    h = get_history
    h.delete_if{|i,n|
      App.i.page_info_is_same_tab(  i , info )
    }
    h.unshift( [ info , name ] )
    set_history( h[0,HISTORY_MAX] )
  end

  def remove( info )
    h = get_history
    h.delete_if{|i,n|
      App.i.page_info_is_same_tab(  i , info )
    }
    set_history( h )
  end

end

