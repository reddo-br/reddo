# -*- coding: utf-8 -*-

# ignore制御スクリプト
#
# コメントやポストを非表示/自動で畳むように設定します
# IgnoreScript.ignore? メソッドを記述することで設定します。
#
# 引数objは link/commentを表わすオブジェクトであり、
# JSONデータと同じkey名(Symbolです)を持つHashです。
# https://github.com/reddit/reddit/wiki/JSON
# 主要なキー
# 共通
#  :kind 種別 t1←コメント t3←リンク
#  :author 投稿したユーザー
#  :subreddit サブレディット名
#  :score スコア
#  :created_utc 作成時刻(unix時間)
# コメントのキー
#  :body コメントの内容(markdown)
# リンクポストのキー
#  :domain ドメイン
#  :over_18 nswf
#  :url リンクのurl
#  :is_self テキスト投稿かどうか
#  :selftext テキスト投稿のテキスト(markdown)
#
# 戻り値は次のいずれかを返してください。
# SHOW: link/commentを表示します。
# IGNORE: linkを表示しません/commentは自動で折り畳まれます。
# HARD_IGNORE linkを表示しません/commentは表示されません(子コメントも表示されません)
#
# 以下はユーザー名とコメントのスコアで表示を制御する例です。

module IgnoreScript

  # ignoreするユーザー名を列挙します
  # 例: IGNORE_AUTHORS = [ "user1" , "user2" ]
  IGNORE_AUTHORS = [ ]

  # この値より低いスコアのコメントを畳みます。nilで全て表示します。
  # 例:MIN_COMMENT_SCORE = -10
  MIN_COMMENT_SCORE = 0

  module_function
  def ignore?( obj )

    if MIN_COMMENT_SCORE and obj[:kind] == 't1' and 
        obj[:score] and obj[:score] < MIN_COMMENT_SCORE
      IGNORE
    elsif IGNORE_AUTHORS.find{|a| a.downcase == obj[:author].to_s.downcase }
      IGNORE
    else
      SHOW
    end
  end

end

