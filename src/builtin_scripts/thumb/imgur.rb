
class ImgurThumb < ThumbnailScript
  def get_thumb( url )
    if m = url.match( %r!https?://(?:i\.)?imgur\.com/([^\. /]+)[^ /]*$! )
      id = m[1]
      # "https://i.imgur.com/#{id}s.jpg" # 90x90
      "https://i.imgur.com/#{id}m.jpg" # 
    else
      nil
    end
  end
end

