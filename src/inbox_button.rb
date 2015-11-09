# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'glyph_awesome'
require 'html/html_entity'
require 'app_color'

import 'org.controlsfx.control.PopOver'

class InboxButton < Java::JavafxSceneControl::ToggleButton
  include JRubyFX::DSLControl

  def initialize
    @glyph = GlyphAwesome.make('ENVELOPE_ALT')
    @glyph_message = GlyphAwesome.make('ENVELOPE_ALT')
    @glyph_message.setColor( Color.web( App.i.theme::COLOR::RED ) )
    
    super("0" , @glyph)
    getStyleClass().add("inbox-button")
    @unread_count = 0
    @popover = UnreadPopOver.new
    
    setOnAction{|ev|
      if selected
        @popover.show( self , 0)
      else
        @popover.hide
      end
    }

    Thread.new{
      sleep( 5 )
      loop{
        mes = []
        begin
          mes = get_inbox_unread
        rescue
          
        end
      
        Platform.runLater{
          set_num( mes.length )
          @popover.set_items( mes )
        }
        
        sleep(60)
      }
    }

  end

  def set_num( num )
    if num > 0
      setStyle("-fx-text-fill:#{App.i.theme::COLOR::RED}")
      setGraphic( @glyph_message )
    else
      setStyle("")
      setGraphic( @glyph )
    end

    setText( num.to_s )
  end

  def popoverHidden
    setSelected(false)
  end

  def get_inbox_unread
    all_account_messages = []
    Account.list.each{|account_name|
      cl = App.i.client( account_name )
      all_account_messages += cl.my_messages( "unread" , count:100 )
    }
    uh = UrlHandler.new
    all_account_messages.each{|m|
      if m[:context].to_s.length > 0
        url = uh.linkpath_to_url( m[:context] )
        page_info = uh.url_to_page_info( url )
        page_info[:account_name] = m[:dest]
        page_info_full = page_info.dup
        page_info_full.delete(:top_comment)
        page_info_full.delete(:context)
        
        m[:reddo_page_info] = page_info
        m[:reddo_page_info_full] = page_info_full
      end
    }
    
    all_account_messages.sort_by{|m| m[:created_utc] }.reverse
  end

end

class UnreadPopOver < PopOver
  WIDTH = 300
  def initialize
    bp = BorderPane.new
    head = BorderPane.new
    head.setCenter( Label.new("未読メッセージ"))
    head_right = HBox.new
    head_right_items = []
    head_right_items <<  @read_button = Button.new("全て既読に") 
    head_right_items <<  @web_button = Button.new("webで")
    head_right_items.each{|i| HBox.setMargin(i, Insets.new( 3, 3 ,3 ,3)) }
    head_right.getChildren.setAll( head_right_items )
    head.setRight( head_right )

    bp.setTop( head )

    @list = ListView.new
    @list.setPrefWidth( WIDTH )
    @list.setPrefHeight( 400 )
    @list.setMaxWidth( WIDTH )
    @list.setPrefHeight( 400 )
    
    bp.setCenter( @list )
    
    BorderPane.setMargin( head , Insets.new(6, 6, 3, 6) )
    BorderPane.setMargin( @list , Insets.new(3, 6, 6, 6) )

    super( bp )
    if App.i.pref['use_dark_theme']
      bp.setStyle("-fx-background-color:#161616;")
    end
    #####
    
    @web_button.setOnAction{|ev|
      App.i.open_external_browser( "https://www.reddit.com/message/inbox/" )
    }
    @read_button.setOnAction{|ev|
      users = @items_observable.to_a.map{|m| m[:dest] }.uniq
      if @items_observable.length > 0
        set_items( [] )
        getOwnerNode.set_num( 0 )
        
        Thread.new{
          users.each{|an|
            cl = App.i.client(an)
            if cl
              begin
                cl.read_all_messages
              rescue
                
              end
            end
          }
        } # thread
      end
    }

    @items_observable = FXCollections.synchronizedObservableList(FXCollections.observableArrayList)
    @list.setItems( @items_observable)

    @list.setCellFactory{|list|
      InboxCell.new( self )
    }
    
    setAutoHide( true )
    setHideOnEscape( true )
    setArrowLocation( PopOver::ArrowLocation::TOP_RIGHT )

    setOnAutoHide{|e|
      self.getOwnerNode.popoverHidden
    }

  end

  def set_items( items )
    @items_observable.setAll( items )
  end

  def self_close
    getOwnerNode.popoverHidden
    hide
  end

  class InboxCell < Java::JavafxSceneControl::ListCell
    include JRubyFX::DSLControl
    def initialize( popover = nil )
      super()
      @popover = popover
      @vbox = VBox.new
      # @h1 = HBox.new
      @h1 = FlowPane.new
      h1_items = []
      h1_items << @type_label = Label.new
      h1_items << @from_label = Label.new
      h1_items << Label.new("から")
      h1_items << @to_label = Label.new
      @h1.getChildren().addAll( h1_items )
      h1_items.each{|i| FlowPane.setMargin( i , Insets.new( 0 , 3  , 0 , 3 )) }

      if App.i.pref["artificial_bold"]
        @type_label.setStyle("-fx-effect: dropshadow( one-pass-box , black , 0,0,1,0 );")
      else
        @type_label.setStyle("-fx-font-weight: bold;")
      end
      
      [@from_label , @to_label].each{|l| l.setStyle( "-fx-text-fill:#{App.i.theme::COLOR::DARK_BLUE}" )}

      @summary  = Hyperlink.new
      @submission = Hyperlink.new
      @summary.setOnAction{|ev|
        if page_info = @summary.getUserData()
          # $stderr.puts page_info
          App.i.open_by_page_info( page_info )
        end
        # @popover.self_close
      }
      @submission.setOnAction{|ev|
        if page_info = @submission.getUserData()
          # $stderr.puts page_info
          App.i.open_by_page_info( page_info )
        end
        # @popover.self_close
      }
      
      @vbox.getChildren.addAll( @h1 , @summary , @submission )
      @vbox.setMaxWidth(UnreadPopOver::WIDTH - 30)
      setGraphic( @vbox )
      # setMaxWidth( 290 )
    end

    def updateItem( inboxObj , is_empty )
      if inboxObj and not is_empty
        # p inboxObj
        # p inboxObj.class
        @h1.setVisible( true )
        if inboxObj[:kind] == 't1'
          @type_label.setText( "(コメント)" )
          @submission.setVisible(true)
          @submission.setText( "コメント全体を見る" )
          @submission.setUserData( inboxObj[:reddo_page_info_full] )
          @summary.setUserData( inboxObj[:reddo_page_info] )
        elsif inboxObj[:kind] == 't4'
          @type_label.setText( Html_entity.decode(inboxObj[:subject]) )
          @submission.setVisible(false)
          @summary.setUserData( {:type => "other" , 
                                  :url => 'https://www.reddit.com/message/messages'
                                })
        end

        @summary.setText( Util.to_text( Html_entity.decode(inboxObj[:body_html] )))

        # @type_label.setText( Html_entity.decode(inboxObj[:subject]) )
        @from_label.setText( inboxObj[:author] )
        @to_label.setText( inboxObj[:dest] )
        
      else
        @h1.setVisible(false)
        @summary.setText("")
        @submission.setText("")
      end
    end # def updateItem

  end # class InboxCell

end
