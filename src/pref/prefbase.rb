# -*- coding: utf-8 -*-

require 'json'
require 'pathname'
require 'fileutils'
require 'util'

class Prefbase
  def initialize( path )
    @path = Pathname.new(path) # jruby-9.0.0.0 windows problem
    @m    = Mutex.new

    @tmpdir = Util.get_appdata_pathname / "tmp"
    FileUtils.mkdir_p( @tmpdir )

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
      begin
        o = JSON.load( File.read(@path) )
        if o
          o
        else
          {}
        end
      rescue
        {}
      end
    else
      {}
    end
  end

  def save_hash(h)
    @m.synchronize{
      begin

        temp = Tempfile.create( "tmp" , @tmpdir )
        temp.write( JSON.pretty_generate( h ))
        temp.close # windows - 閉じないと移動できない
        FileUtils.mv( temp.path , @path , {:force => true})
        
      rescue
        $stderr.puts $!
        $stderr.puts $@
      end
    }
  end
end
