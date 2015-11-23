require 'util'
require 'pref/prefbase'

require 'fileutils'
require 'json'

# access_dump: {
#  access_token:
#  refresh_token:
#  scope:
#  expires_at:
# }

class Account < Prefbase
  
  def initialize( name )
    accounts_dir = Util.get_appdata_pathname / "accounts"
    FileUtils.mkdir_p( accounts_dir )
    file = accounts_dir + (name + ".json")
    #p file.to_s
    super( file )
  end

  @@accounts = {}
  def self.byname( name )
    if @@accounts[ name ]
      @@accounts[name]
    else
      a = self.new( name )
      if a['access_dump'] 
        @@accounts[ name ] = a
      end
      a
    end
  end

  def scopes
    if dump = self["access_dump"]
      begin
        json = JSON.parse(dump)
        json["scope"].to_s.split(" ")
      rescue
        []
      end
    else
      []
    end
  end

  def name_to_path( name )
    accounts_dir = Util.get_appdata_pathname / "accounts"
    accounts_dir / ( name + ".json" ) # Pathname class
  end

  def self.list
    accounts = Dir.glob( (Util.get_appdata_pathname + "accounts").to_s + "/*.json").map{|p| 
      File.basename(p,".json")
    }
    #p accounts
    accounts_with_token = accounts.find_all{|n| 
      self.new(n)['access_dump'] 
    }
    #p accounts_with_token
    accounts_with_token
  end

  def self.exist?(name )
    self.list.find{ |a| a == name }
  end

  def self.delete( name )
    File.unlink( name_to_path( name ) )
  end

end
