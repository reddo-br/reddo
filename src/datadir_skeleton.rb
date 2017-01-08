# -*- coding: utf-8 -*-

require 'util'
require 'app'
require 'fileutils'

module DatadirSkeleton
FILES=%w(
scripts/README.txt
)

  module_function
  def setup
    datadir = Util.get_appdata_pathname
    FILES.each{|f|
      local_path = datadir / f
      if not File.exist?(local_path)
        begin
          content = App.res( "/res/datadir_skeleton/#{f}" ).to_io.read
          FileUtils.mkdir_p( File.dirname( local_path.to_s ))
          open( local_path,'w'){|f| f.write content }
        rescue
          $stderr.puts "skeleton準備エラー #{f}"
          $stderr.puts $@
          $stderr.puts $!
        end
      end
    }
  end

end
