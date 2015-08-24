# -*- coding: utf-8 -*-

ENV.each{|k,v|
    puts "#{k} : #{v}"
    ENV[k] = v.dup.force_encoding("utf-8")
}

class File
  class << self
    alias :expand_path_orig :expand_path

    def expand_path( path , default_dir = "." )
      utf8 = expand_path_orig( path , default_dir ).force_encoding("utf-8") # .encode( Encoding.default_external )
    end

    # jrubyfxの非asciiパスからのロードに必要である
    alias :dirname_orig :dirname
    def dirname( path )
      dirname_orig( path.dup.force_encoding("utf-8"))
    end

  end

end

# jruby-9.0.0.0 非ascii文字を含むパスからのロード
# 外部から取得した Stringの encoding は場合によりまちまちで、実際のエンコードと一致していない

module Kernel
  alias :require_orig :require

  REDDO_CANDIDATE_ENCODES = [ nil , 'utf-8','Windows-31J' ] # + Encoding.list.map{|l|l.to_s}

  def require( path )
    $stderr.puts "*** Patched require: path #{path}"
    candidate_encodes = REDDO_CANDIDATE_ENCODES.dup
    begin
      enc = candidate_encodes.shift
      if enc
        $stderr.puts "patched require: try #{enc}"
        require_orig( path.force_encoding(enc))
      else
        require_orig( path )
      end
    rescue Exception
      if candidate_encodes.length > 0
        retry
      else
        raise
      end
    end
  end

  alias :load_orig :load
  def load( path , priv = false)
    $stderr.puts "*** patched load #{path}"
    candidate_encodes = REDDO_CANDIDATE_ENCODES.dup
    begin
      enc = candidate_encodes.shift
      if enc
        $stderr.puts "patched load: try #{enc}"
        load_orig( path.force_encoding(enc) , priv)
      else
        load_orig( path , priv)
      end
    rescue Exception
      if candidate_encodes.length > 0
	retry
      else
        raise
      end
    end


  end

  #module_function
  #def autoload( const , feature )
  #  $stderr.puts "*** patched autoload"
  #  require( feature )
  #end

end # Kernel
