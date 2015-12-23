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
    $stderr.puts "old account:#{old}"
    @selection = Account.list + [NOT_LOGIN]
    getItems.setAll( *@selection )
    if @selection.find{|a| a == ( old||NOT_LOGIN )  }
      set_account( old )
    else
      set_account( nil )
      @change_cb.call if @change_cb
    end
    @enable_change_cb = true
  end

  def set_change_cb(&cb)
    @change_cb = cb
  end

  def set_account( name )
    if name
      if is_exist_account(name)
        getSelectionModel.select( name )
      else
        getSelectionModel.select( NOT_LOGIN )
      end
    else
      getSelectionModel.select( NOT_LOGIN )
    end
  end

  def is_exist_account( name )
    getItems.find{|i| i == (name || NOT_LOGIN )}
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
