require 'pref/prefbase'
require 'util'

class Subs < Prefbase
  def initialize( subname )
    subs_dir = Util.get_appdata_pathname + "subs"
    FileUtils.mkdir_p( subs_dir )

    file = subs_dir + ( subname + ".json")
    super(file)

  end
  
end # class
