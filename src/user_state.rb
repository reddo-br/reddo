# -*- coding: utf-8 -*-
require 'pref/account'
require 'app'

class UserState

  @@cache = {}
  def self.from_username( username , site:"reddit" )
    @@cache[ [username,site] ] || ( @@cache[[username,site]] = self.new( username ,site) )
  end

  def initialize( username,site)
    @username = username
    @site = site
    @modified = nil
    @m = Mutex.new
  end
  attr_reader :user ,:is_shadowbanned

  def refresh
    @m.synchronize{
      if not @modified or (@modified + 180 < Time.now)
        if Account.exist?( @username )
          cl = App.i.client( @username )
          @user = cl.me
          
          ## test
          #if @user[:name] == 'reddo_br2'
          #  @user[:is_suspended] = true
          #  @user[:suspension_expiration_utc] = (Time.now + 3600).to_i
          #end

          cl_nouser = App.i.client(nil)
          begin
            cl_nouser.user_from_name( @username )
            @is_shadowbanned = false
          rescue Redd::Error::NotFound
            @is_shadowbanned = true
          rescue
            $stderr.puts $!
            $stderr.puts $@
          end
          
        end
        @modified = Time.now
      else
        $stderr.puts "ユーザー情報:キャッシュ利用"
      end
    }
  end # refresh

end
