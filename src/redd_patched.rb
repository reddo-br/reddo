# -*- coding: utf-8 -*-
require 'redd'

module Redd
  module Clients

    class Base
      def reset_connection
        @connection = nil
      end
    end

  end

  module Objects
    
    class Submission 
      def expand_more_hack(more , sort:"new")
        response = client.get(
          "/api/morechildren",
          children: more.join(","),
          link_id: fullname,
          sort:sort
        )

        client.object_from_body(
          kind: "Listing",
          data: {
            before: "", after: "",
            children: response.body[:json][:data][:things]
          }
        )
      end
    end

    class MoreComments
      attr_accessor :parent_id , :count
      def initialize(  _, attributes)
        super(attributes[:children])
        @parent_id = attributes[:parent_id]
        @count = attributes[:count].to_i
      end
      
    #   def parent_id
    #     @parent_id
    #   end
    #   def count
    #     @count
    #   end
      
    end

  end # module Objects

  

end


