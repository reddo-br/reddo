# -*- coding: utf-8 -*-
require 'pref/prefbase'
require 'util'
require 'url_handler'
class Subs < Prefbase
  def initialize( subname , site:"reddit")
    @site = site || 'reddit'
    @url_handler = UrlHandler.new( site:site )
    subs_dir = Util.get_appdata_pathname + "subs"
    FileUtils.mkdir_p( subs_dir )
    
    file = subs_dir + ( pref_subname(subname) + ".json")
    super(file)
  end

  def default
    {"dont_use_user_flair_style" => true}
  end
  
  def pref_subname(subname)
    if subname.to_s == "../"
      "_"
    else
      # subの場合,idではない
      @site + subname_to_pathname(subname).gsub(/\// , "." )
    end
  end

  def subname_to_pathname(name)
    @url_handler.subname_to_url(name).path
  end

end # class
