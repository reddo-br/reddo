class TwimgThumbnail < ThumbnailScript

  def enabled?
    true
  end

  def get_thumb( url )
    if url.match( %r!https?://.+\.twimg\.com/.*! )
      url.gsub(/:[^:\/]+$/,'') + ":small"
    else
      nil
    end
  end

end
