# -*- coding: utf-8 -*-

require 'util'
require 'user_script_base'

# buildin
require 'builtin_scripts/thumb/imgur'
require 'builtin_scripts/thumb/youtube'

module UserScriptLoader
  module_function
  def load
    script_dir = Util.get_appdata_pathname / 'scripts'
    scripts = Dir.glob( "#{script_dir.to_s}/**/*.rb" )
    p scripts
    scripts.each{|path|
      begin
        $stderr.puts "ユーザースクリプトロード: #{path}"
        Kernel.load( path )
      rescue
        $stderr.puts "スクリプトロードエラー #{path}"
        $stderr.puts $@
        $stderr.puts $!
      end
    }
  end
end

