# -*- coding: utf-8 -*-
require 'java'
# require './lib/java/mapdb-1.0.8.jar'
import 'org.mapdb.DBMaker'

require 'fileutils'

class ReadCommentDB
  include Singleton

  def initialize
    dbpath = ((Util.get_appdata_pathname + "db") + "read_comment.db")
    FileUtils.mkdir_p( File.dirname( dbpath.to_s ))
    @db = DBMaker.newFileDB( java.io.File.new(dbpath.to_s) ).closeOnJvmShutdown().make()
  end

  def add( comment_ids )
    if not comment_ids.kind_of?(Array)
      comment_ids = [ comment_ids ]
    end

    map = @db.getHashMap("read")
    comment_ids.each{|comment_id|
      map.put( comment_id, true )
    }
    @db.commit()
  end

  def is_read( comment_id )
    map = @db.getHashMap("read")
    map.get( comment_id )
  end

  def set_count( subm_id , count )
    map = @db.getHashMap("count")
    map.put( subm_id , count )
    @db.commit()
  end

  def get_count( subm_id )
    map = @db.getHashMap("count")
    map.get( subm_id )
  end

  def set_subm_account( subm_id , account_name )
    map = @db.getHashMap("subm_account")
    if account_name == nil # falseは書く
      map.remove( subm_id )
    else
      map.put( subm_id , account_name )
    end
    @db.commit()
  end

  def get_subm_account( subm_id )
    map = @db.getHashMap( "subm_account")
    map.get( subm_id )
  end

  def close
    @db.close()
  end
end
