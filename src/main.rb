# -*- coding: utf-8 -*-

module Kernel
   alias require gem_original_require 
end

$stderr.puts "#{$LOAD_PATH}"
$stderr.puts

require 'drb_wrapper'
begin
  if s = DRbObject.new_with_uri( DrbWrapper::DRB_URI )
    if s.alive? == 'ok'
      $stderr.puts "すでにクライアントが起動しています"
      s.focus
      exit
    end
  end
rescue
  $stderr.puts $!
  $stderr.puts $@
end

require 'app'
App.instance.run
