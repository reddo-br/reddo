# -*- coding: utf-8 -*-

module Kernel
   alias require gem_original_require 
end

require 'jruby_patch'
require 'java'
$stderr.puts "#{$LOAD_PATH}"
$stderr.puts
require 'commandline_options'
$opts = CommandlineOptions.new(ARGV)
require 'drb_wrapper'
begin
  if s = DRbObject.new_with_uri( DrbWrapper::DRB_URI )
    if s.alive? == 'ok'
      $stderr.puts "すでにクライアントが起動しています"
      s.focus

      # $stderr.puts "argv: #{ARGV}"
      if url = ARGV.shift
        s.open(url)
      end
      java.lang.System.exit(0)
      #exit(0)
    end
  end
rescue
  $stderr.puts $!
  $stderr.puts $@
end

require 'app'
App.instance.run
