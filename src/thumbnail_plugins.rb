# -*- coding: utf-8 -*-

require 'user_script_base'

class ThumbnailPlugins
include Singleton

  def initialize
    @plugins = []
    ObjectSpace.each_object(Class){|c|
      if c.superclass == ThumbnailScript
        o = c.new
        if o.enabled?
          @plugins << o
        end
      end
    }
    @plugins.sort_by{|c| c.priority }.reverse!
    $stderr.puts "サムネイルプラグイン:#{@plugins.map{|o|o.class.to_s}}"
  end

  def plugins
    @plugins
  end

end
