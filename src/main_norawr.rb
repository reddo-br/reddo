# -*- coding: utf-8 -*-
require 'jruby_patch'

#require 'java'
#require 'jrubyfx'
require 'commandline_options'
$opts = CommandlineOptions.new(ARGV)
require 'drb_wrapper'
begin
  if s = DRbObject.new_with_uri( DrbWrapper::DRB_URI )
    if s.alive? == 'ok'
      $stderr.puts "すでにクライアントが起動しています"
      s.focus

      if url = ARGV.shift
        s.open(url)
      end
      exit
    end
  end
rescue
  $stderr.puts $!
  $stderr.puts $@
end

require 'java'
require 'jrubyfx'
require './lib/java/controlsfx-8.40.10.jar'
require './lib/java/mapdb-1.0.8.jar'
require './lib/java/commons-lang3-3.4.jar'
# require './lib/java/unbescape-1.1.1.RELEASE.jar'

require 'app'
App.instance.run
