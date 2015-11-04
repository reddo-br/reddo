# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'client_params'
require 'cgi'
require 'webrick'

module WEBrick
  module Utils
    def create_listeners(address, port, logger=nil)
      unless port
        raise ArgumentError, "must specify port"
      end
      sockets = Socket.tcp_server_sockets(address, port)
      sockets = sockets.map {|s|
        s.setsockopt(:SOCKET, :REUSEADDR, true)
        s.autoclose = false
        ts = TCPServer.for_fd(s.fileno)
        s.close
        ts
      }
      return sockets
    end
    module_function :create_listeners
  end
end

class AuthWindow < Java::JavafxStage::Stage
  include ClientParams
  
  SCOPE = [ "identity" , "read" , "submit" , "edit",
            "vote" , "subscribe" , "save" , "report" , 
            "privatemessages" , 
            "creddits" , # not credits
            "mysubreddits" # 購読リストに必要
          ]
  
  def initialize( )
    super()
    if App.i.pref['use_dark_theme']
      sceneProperty.addListener{|ev|
        if s = ev.getValue()
          s.getStylesheets().add( App.res_url("/res/dark.css") )
        end
      }
    end
    
    @auth_state = "mftWfct" + rand.to_s
    
    @cl = Redd.it(:web, CLIENT_ID, nil , REDIRECT_URI , 
                  user_agent:USER_AGENT) # codeがおくれない
    initModality(Modality::WINDOW_MODAL)
    initOwner( App.i.stage )
    setWidth( 500 )
    setHeight( 400 )

    setTitle( "OAuth認証" )
    
    root = VBox.new( 5.0 )
    root.setAlignment( Pos::TOP_CENTER )
    
    label_desc = Label.new("下のボタンから、Webブラウザを開いて(必要なら認証するアカウントでログインして下さい)、Reddoブラウザによるアクセスを許可してください")
    label_desc.setWrapText(true)
    label_desc.setStyle("-fx-font-size:120%")
    
    root.getChildren().add( label_desc )
    root.class.setMargin( label_desc , Insets.new( 3 ,3 , 3 , 3 ))

    button = Button.new("認可ページを開く")
    button.setOnAction{|ev|
      open_auth_page
    }
    button2 = Button.new("URLをコピー")
    button2.setOnAction{|ev|
      copy_auth_page
    }
    bh = HBox.new()
    bh.setAlignment( Pos::CENTER )
    bh.getChildren().setAll( button , button2)

    root.getChildren().add( bh )

    button_close = Button.new("閉じる")
    root.getChildren().add( button_close)
    button_close.setOnAction{|ev|
      shut_server
      close()
    }

    @fin_label = Label.new("")
    @fin_label.setWrapText(true)
    root.getChildren().add( @fin_label )

    # getScene().setRoot(root)
    setScene( Scene.new( root ))

    start_server

    setOnCloseRequest{|ev|
      # $stderr.puts "リダイレクトサーバー shutdown"
      shut_server
    }

  end

  def open_auth_page
    url = @cl.auth_url( @auth_state , SCOPE , :permanent)
    App.i.open_external_browser(url)
  end

  def copy_auth_page
    url = @cl.auth_url( @auth_state , SCOPE , :permanent)
    # App.i.open_external_browser(url)
    clip = Clipboard.getSystemClipboard()
    content = ClipboardContent.new()
    content.putUrl( url )
    content.putString( url )
    clip.setContent( content )
  end

  def shut_server
    if @@srv
      @@srv.shutdown
      while not @@srv.status == :Stop
        sleep( 0.1 )
      end
      @@srv = nil
    end
  end

  # けっきょくうまくいかない
  # class HTTPServerReuseAddr < WEBrick::HTTPServer
  #   def listen( address , port )
  #     $stderr.puts "overriden listen()"
  #     socks = WEBrick::Utils::create_listeners(address, port, @logger)
  #     socks.each{|s| s.setsockopt(:SOCKET, :REUSEADDR, true) }
  #     @listeners += socks
  #     setup_shutdown_pipe
  #   end 
  # end

  @@srv = nil
  def start_server
    # todo: listenソケットをreuseaddrすることはできないのか？
    
    if not @@srv
      @@srv = WEBrick::HTTPServer.new(:DocumentRoot => nil ,
                                      # :BindAddress => "0.0.0.0",
                                      :BindAddress => "127.0.0.1",
                                      :Port => 32323
                                      )
    
      @@srv.mount_proc("/auth_redirect"){|req,res|
        uri = req.request_uri
        params = CGI.parse( uri.query )
        
        # p params # {"state"=>["tttpwefxw0.3744852795590342"], "code"=>["8e1Q4cz-RWO4cPpGO5Chsl6M6_E"]}

        if params['state'][0] == @auth_state
          begin
            @cl.authorize!( params['code'][0] )
            
            json = @cl.access.to_json
            # 名前をチェックする
            user_name = @cl.me.name
            ac = Account.byname( user_name )
            ac['access_dump'] = @cl.access.to_json
            
            res.body = make_html("#{ClientParams::APP_NAME}:認可を受け取りました。アプリケーションに戻ってください。")
            
            Platform.runLater{
              @fin_label.setText("認可を受け取りました。アカウント名:#{user_name}")
              ass =  App.i.root.lookupAll(".account-selector")
              ass.each{|as|
                as.load_accounts()
              }
            }
          rescue
            $stderr.puts $!
            $stderr.puts $@
            res.body = make_html("認証に失敗しました。#{$!}")
          end        
        else
          res.body = make_html("認証に失敗しました。")
        end
      }
      Thread.new{
        @@srv.start
      }
    end
    
  end

  def make_html( message )
    html = <<EOF
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
</head>
<body>
#{message}
</body></html>
EOF
    html
  end

end
