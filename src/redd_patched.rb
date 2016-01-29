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
        response = client.post(
          "/api/morechildren",
          children: more.join(","),
          link_id: fullname,
          sort:sort
        )

        ret = client.object_from_body(
          kind: "Listing",
          data: {
            before: "", after: "",
            children: response.body[:json][:data][:things]
          }
        )
        
        # todo: clientがloginしてない場合、morechildrenの内容がhtmlの内容だけになる
        # 例： https://www.reddit.com/r/redditdev/comments/31z6ln/more_children_comments_format_and_schema_issue/
        # 他のブラウザでは、afterパラメタ等を駆使して代用している？

        ret
      end
    end

    class MoreComments
      attr_accessor :parent_id , :count , :id
      def initialize(  _, attributes)
        super( attributes[:children] )
        @parent_id = attributes[:parent_id]
        @id = attributes[:id]
        @count = attributes[:count].to_i
      end
      
    end

  end # module Objects

  class Error < StandardError
    class RateLimited < Error
      def initialize(env)
        p env
        @time = env[:body][:json][:ratelimit] || 60*60
        super
      end
    end

    def self.parse_error(body) # rubocop:disable all
      return "NOT_HASH" unless body.is_a?(Hash) # どうせhashでなければerrorは作れない

      if body.key?(:json) && body[:json].key?(:errors)
        body[:json][:errors].first
      elsif body.key?(:jquery)
        body[:jquery]
      elsif body.key?(:error)
        body[:error]
      elsif body.key?(:code) && body[:code] == "NO_TEXT"
        "NO_TEXT"
      end
    end


  end

end
