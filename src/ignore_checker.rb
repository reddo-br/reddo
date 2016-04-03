# -*- coding: utf-8 -*-

require 'singleton'
require 'util'

class IgnoreChecker
  include Singleton
  
  def initialize
    @cache = {}
  end

  def check( obj )
    if v = @cache[ obj[:name] ]
      v
    else
      @cache[ obj[:name] ] = IgnoreScript.ignore?( obj )
    end
  end

end
