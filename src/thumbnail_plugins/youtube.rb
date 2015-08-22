require 'uri'
class YoutubeThumb
  def get_thumb( url_string )
    begin
      url = URI.parse(url_string)
      # p url
      if url.host == 'www.youtube.com'
        kvs = url.query.to_s.split("&").map{|kv| kv.split("=") }
        if v_vid = kvs.assoc("v")
          vid = v_vid[1]
          id_to_thumb( url , vid )
        else
          nil
        end
      elsif url.host == 'youtu.be'
        vid = File.basename( url.path )
        id_to_thumb( url , vid )
      else
        nil
      end # hostname
    rescue
      nil
    end
  end

  def id_to_thumb( url , vid )
    "<a href=\"#{url}\"><img src=\"http://img.youtube.com/vi/#{vid}/1.jpg\"></a>"
  end

end

$thumbnail_plugins << YoutubeThumb.new

