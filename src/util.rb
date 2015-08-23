# -*- coding: utf-8 -*-

require 'java'
require 'pathname'
require 'rbconfig'
require 'fileutils'

#require 'app'
require 'client_params'
require 'html/html_entity'

module Util
  USER_DIR_NAME = ClientParams::APP_NAME.downcase
  def get_appdata_pathname
    path = 
      case get_os
      when "unixlike"
        Pathname.new(Dir.home) + ("." + USER_DIR_NAME)
      when "macosx"
        Pathname.new(Dir.home) + "Library" + "Application Support" + USER_DIR_NAME
      when "windows"
        # jruby-9.0.0.0 acturally utf-8
        Pathname.new(ENV['APPDATA'].dup.force_encoding("utf-8")) + USER_DIR_NAME
      end

    FileUtils.mkdir_p( path )
    #if get_os != 'windows'
    set_user_dir_permission( path.to_s )
    #end
    path
  end
  module_function :get_appdata_pathname

  # 
  def get_os
    osstring = RbConfig::CONFIG['host_os']
    case osstring
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      "windows"
    when /darwin|mac os/
      "macosx"
    else
      "unixlike"
    end
  end
  module_function :get_os

  def toggle_group_set_listener_force_selected( toggle , default )
    cb = Proc.new
    old_selected = default
    toggle.selectToggle( old_selected )
    toggle.selectedToggleProperty().addListener{|obj|
      new_selected = obj.getValue()
      if new_selected
        if old_selected != new_selected
          old_selected = new_selected
          cb.call( new_selected )
        end
      else
        # 必ずどれかが選択された状態に
        toggle.selectToggle( old_selected )
      end
    }
  end
  module_function :toggle_group_set_listener_force_selected

  def set_user_dir_permission( dir )
    begin
      jf = java.io.File.new( dir )

      jf.setWritable( false , false )
      jf.setWritable( true , true )

      jf.setExecutable( false , false )
      jf.setExecutable( true , true )

      jf.setReadable( false , false )
      jf.setReadable( true , true )
    rescue
      $stderr.puts $!
      $stderr.puts $@
    end
  end
  module_function :set_user_dir_permission

  def find_submission_preview( obj , min_height:nil , max_height:nil , 
                               min_width:nil , max_width:nil ,
                               prefer_large:false)
    prevs = (p1 = obj[:preview]) && (p2 = p1[:images]) && (p3 = p2[0]) && (p3[:resolutions])

    if prevs
      prevs1 = prevs.find_all{|p| 
        ((min_height == nil ) or p[:height] >= min_height ) and
        ((max_height == nil ) or p[:height] <= max_height ) and
        ((min_width  == nil ) or p[:width]  >= min_width  ) and
        ((max_width  == nil ) or p[:width]  <= max_width  )
      }
      if prevs1.length > 0
        target = if prefer_large
                   prevs1.max_by{|p| p[:height]}
                 else
                   prevs1.min_by{|p| p[:height]}
                 end
        $stderr.puts "preview画像を使う w:#{target[:width]} h:#{target[:height]}"
        [target[:url] , target[:width] , target[:height] ]
      else
        nil
      end
    else
      nil
    end
  end
  module_function :find_submission_preview
end # module
