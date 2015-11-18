# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'app'

class UserBanStateLabel < Java::JavafxSceneControl::Label
  include JRubyFX::DSLControl
  
  def initialize( user_info = nil , shadowbanned = false)
    super()
    setStyle("-fx-background-color:#{App.i.theme::COLOR::STRONG_RED}; -fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}")
    set_data( user_info , shadowbanned )
  end

  def set_data( user_info , shadowbanned )
    if shadowbanned
      setText("Shadowbanned")
      setTooltip(nil)
    elsif user_info and user_info[:is_suspended]
      setText("アカウント停止中")
      limit_str = if user_info[:suspension_expiration_utc]
                    Time.at( user_info[:suspension_expiration_utc]).strftime("%Y-%m-%d %H:%M:%S")
                  else
                    "無期限"
                  end
      setTooltip( Tooltip.new("期限: #{limit_str}"))
    else
      setText("")
      setTooltip(nil)
    end
  end

end
