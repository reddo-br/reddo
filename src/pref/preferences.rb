
require 'util'
require 'pref/prefbase'

class Preferences < Prefbase

  def initialize
    @file = Util.get_appdata_pathname + "preferences.json"
    super( @file )
  end

end
