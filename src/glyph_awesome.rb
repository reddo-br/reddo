require 'java'
require 'jrubyfx'

# require './lib/java/controlsfx-8.40.9.jar'
import 'org.controlsfx.glyphfont.Glyph'

module GlyphAwesome
  module_function
  def make( name ,size:(11.5) , gradient:false , hover:true , color:nil)
    glyph_name = name.to_s
    glyph = Glyph.new( 'FontAwesome' , glyph_name )
    glyph.size( size ) if size
    glyph.useGradientEffect if gradient
    glyph.useHoverEffect if hover
    glyph.color( Color.web( color )) if color.is_a?(String)
    glyph
  end
end
