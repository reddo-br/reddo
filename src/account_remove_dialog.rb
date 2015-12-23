# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'app'
require 'progress_dialog'
require 'pref/account'

class AccountRemoveDialog < ProgressDialog
  def initialize(account_name)
    super( "アカウント登録の解除",
           "アカウント #{account_name} がreddoに与えているアクセス権限を解除し、アプリのアカウント選択リストから除きます"){
      remove_account( account_name )
      "終了しました"
    }

  end

  def remove_account( account_name )
    cl = App.i.client( account_name )
    cl.revoke_access!

    Account.delete( account_name )

    App.i.refresh_account_selectors
  end
  
end
