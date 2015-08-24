# -*- coding: utf-8 -*-
require 'jruby_patch'

require 'java'
require 'jrubyfx'

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

require 'java'
require './lib/java/controlsfx-8.40.9.jar'
require './lib/java/mapdb-1.0.8.jar'
require './lib/java/commons-lang3-3.4.jar'

require 'app'
App.instance.run
