
require 'kramdown/parser/kramdown'
# require 'kramdown/parser/kramdown/link'
module Kramdown
  module Parser
    class Kramdown
      LINK_START = /\[(?=[^^])/
      # LINK_START = /(?<!\!)\[(?=[^^])/

      @@parsers.delete( :link )
      define_parser(:link , LINK_START, '\[')
      # define_parser(:link , LINK_START, nil)
    end

  end
end

### enable table
require 'kramdown/parser/markdown'
$reddit_extended = Kramdown::Parser::Markdown::EXTENDED + [:block_html] - [:table]
p $reddit_extended
module Kramdown
  module Parser
    class Markdown < Kramdown
      EXTENDED = $reddit_extended
    end
  end
end

require 'kramdown'
