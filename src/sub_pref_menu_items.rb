# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

module SubPrefMenuItems
  def create_sub_pref_menu_items( parent_menu , subname  , site:"reddit")
    subpref = Subs.new( subname , site:site )
    use_link_style_item = CheckMenuItem.new("リンクのスタイルを再現する")
    use_link_style_item.setOnAction{|ev|
      subpref[ 'dont_use_link_style' ] = (not use_link_style_item.isSelected )
    }

    use_user_flair_style_item = CheckMenuItem.new("ユーザーフレアのスタイルを再現する")
    use_user_flair_style_item.setOnAction{|ev|
      subpref['dont_use_user_flair_style'] = (not use_user_flair_style_item.isSelected)
    }

    sjis_art_item = CheckMenuItem.new("整形済テキストにAA用フォントを使う")
    sjis_art_item.setOnAction{|ev|
      subpref['dont_use_sjis_art'] = (not sjis_art_item.isSelected)
    }
    
    parent_menu.setOnShowing{|ev|
      use_link_style_item.setSelected( (not subpref['dont_use_link_style'] ))
      use_user_flair_style_item.setSelected( (not subpref['dont_use_user_flair_style'] ))
      sjis_art_item.setSelected( (not subpref['dont_use_sjis_art'] ))
    }

    parent_menu.getItems.setAll( 
                                [ use_link_style_item , 
                                  use_user_flair_style_item ,
                                  sjis_art_item
                                ]
                                )
  end
end
