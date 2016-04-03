
module IgnoreScript
  
  IGNORE = 'ignore'
  HARD_IGNORE = 'hard_ignore'
  SHOW = 'show'
  
  module_function
  def ignore?( obj )
    SHOW
  end

end

class ThumbnailScript

  def get_thumb(url)
    nil
  end

  def priority
    0
  end

  def enabled?
    true
  end

end
