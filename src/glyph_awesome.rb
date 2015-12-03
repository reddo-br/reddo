# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

import 'org.controlsfx.glyphfont.Glyph'
import 'org.controlsfx.glyphfont.GlyphFont'
import 'org.controlsfx.glyphfont.GlyphFontRegistry'

require 'app'

module GlyphAwesome

  module_function
  def make( name ,size:(11.5) , gradient:false , hover:true , color:nil)
    glyph_name = name.to_s

    if not defined?( @@gf )
      # $stderr.puts "グリフをロード"
      GlyphFontRegistry.register("fontawesome" ,
                                 App.res( '/res/fontawesome-webfont.ttf'),
                                 11.5 )
      @@gf = GlyphFontRegistry.font("fontawesome")
    end
    # glyph = Glyph.new( 'FontAwesome' , glyph_name )
    glyph = @@gf.create( glyph_name )
    glyph.size( size ) if size
    glyph.useGradientEffect if gradient
    glyph.useHoverEffect if hover
    glyph.color( Color.web( color )) if color.is_a?(String)
    glyph
  end
end
