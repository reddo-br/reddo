
require 'json'
require 'pathname'

class Prefbase
  def initialize( path )
    @path = Pathname.new(path)
    @m    = Mutex.new
  end
  
  def set( key ,val )
    h = load_hash
    h[key] = val
    save_hash(h)
  end

  def get( key )
    load_hash[ key ]
  end

  def []=( key , val )
    set( key , val )
  end

  def [] ( key )
    get( key )
  end

  private
  def load_hash
    if @path.exist?
      JSON.load( File.read(@path) )
    else
      {}
    end
  end

  def save_hash(h)
    @m.synchronize{
      begin
        open( @path , 'a'){|f|
          if f.flock( File::LOCK_EX | File::LOCK_NB )
            f.truncate(0)
            f.write( JSON.pretty_generate( h ))
            f.flock( File::LOCK_UN )
          end
        }
      rescue
        $stderr.puts $!
        $stderr.puts $@
      end
    }
  end
end
