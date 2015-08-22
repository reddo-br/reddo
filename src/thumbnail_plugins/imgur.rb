
class ImgurThumb
  def get_thumb( url )
    if m = url.match( %r!https?://(?:i\.)?imgur\.com/([^\. /]+)[^ /]*$! )
      id = m[1]
      thumb_url = "https://i.imgur.com/#{id}s.jpg"
      "<a href=\"#{url}\"><img src=\"#{thumb_url}\"></a>"
    else
      nil
    end
  end
end

$thumbnail_plugins << ImgurThumb.new
