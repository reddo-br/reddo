# -*- coding: utf-8 -*-
# コメント内のあるurlに対して、コメント下部のサムネイル表示欄に表示されるサムネイルのurlを定義する例です。
# youtubeとimgurについてはアプリ内であらかじめ定義されていますが、ここで上書きすることもできます。

# 設定方法
# ThumbnailScriptを継承したクラスを定義し、必要なメソッドを追加してください。
#
# メソッド:
#  get_thumb( url ) : 引数url(String)に対して、サムネイルのurl(String)を返します。処理対象外のurlならnilを返します。
#  enabled? : trueでこのサムネイル定義クラスが有効になります
#  priority : この値が大きいクラスほど優先して適用されます。デフォルトは0です。


# twimg.comのイメージのサムネイルを表示します。

class TwimgThumbnail < ThumbnailScript

  def enabled?
    false
  end

  def get_thumb( url )
    if url.match( %r!https?://.+\.twimg\.com/.*! )
      url + ":small"
    else
      nil
    end
  end

end


# サムネイルは自動で表示することが前提のため、
# 原則として、サーバー側で軽量なサムネイルが用意されているサイトのurlに対して使用してください。
# しかし以下のクラスでは、あえて生の画像ファイルを直接使います。重くても知りません。

class RawThumbnail < ThumbnailScript

  def enabled?
    false
  end

  def priority
    -1
  end

  def get_thumb( url )
    if url =~ /\.(jpg|jpeg|png|gif|svg)$/i
      url
    else
      nil
    end
  end
end
