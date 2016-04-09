# -*- coding: utf-8 -*-

require 'singleton'
require 'util'

class IgnoreChecker
  include Singleton
  
  def initialize
    @cache = {}
  end

  def check( obj )
    if v = @cache[  keyval(obj)  ]
      v
    else
      @cache[ keyval(obj) ] = IgnoreScript.ignore?( obj )
    end
  end

  def keyval( obj )
    obj[:name] + ":" + obj[:edited].to_s
  end

end
