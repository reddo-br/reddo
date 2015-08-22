# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'pref/account'
require 'app'

class AccountSelector < Java::JavafxSceneControl::ChoiceBox
  include JRubyFX::DSLControl # これを付けると、dslで使える

  def initialize( name = nil)
    super()
    getStyleClass().add("account-selector")
    setMinWidth( 100 )
    load_accounts()
    set_account( name )

    valueProperty().addListener{|ev|
      @change_cb.call if @change_cb and @enable_change_cb
    }

    @enable_change_cb = true
  end

  # 利用可能なアカウントをチェックする

  NOT_LOGIN = "未ログイン"

  def load_accounts()
    @enable_change_cb = false
    old = get_account
    @selection = Account.list + [NOT_LOGIN]
    getItems.setAll( *@selection )
    if Account.list.find{|a| a == (old || NOT_LOGIN ) }
      set_account( old )
    else
      @change_cb.call if @change_cb
    end
    @enable_change_cb = true
  end

  def set_change_cb(&cb)
    @change_cb = cb
  end

  def set_account( name )
    if name
      getSelectionModel.select( name )
    else
      getSelectionModel.select( NOT_LOGIN )
    end
  end

  def get_account
    item = getSelectionModel.getSelectedItem
    if item == NOT_LOGIN
      nil
    else
      item
    end
  end

end
