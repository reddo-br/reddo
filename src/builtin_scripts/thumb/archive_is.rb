class ArchiveIsThumbnail < ThumbnailScript

  def enabled?
    true
  end
  
  def get_thumb(url)
    if url.match( %r!https?://archive\.(is|fo)/[^/]+$! )
      url + "/thumb.png"
    else
      nil
    end
  end

end
