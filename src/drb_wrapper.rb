
require 'drb'
require 'url_handler'
class DrbWrapper
  include DRb::DRbUndumped
  DRB_URI = "druby://127.0.0.1:33876"

  def initialize(app)
    @app = app
    @uh = UrlHandler.new
  end

  def open( url )
    pi = @uh.url_to_page_info( url )
    if pi[:type] != 'other'
        Platform.runLater{
        @app.open_by_page_info( url )
      }
    end
  end

  def focus
    Platform.runLater{
      @app.stage.requestFocus()
    }
  end

  def quit
    Platform.runLater{
      @app.stage.close()
    }
  end

  def alive?
    "ok"
  end

end
