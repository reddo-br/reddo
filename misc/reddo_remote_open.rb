#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'drb'

# 起動しているreddo上で、redditのurlを(対応していれば)開くスクリプトです。
# nativeなrubyでも動作します。
# 例: ruby reddo_remote_open.rb https://www.reddit.com/r/ReddoBrowser/comments/3i2dq7/総合スレ/

if url = ARGV.shift
  begin
    if s = DRbObject.new_with_uri( "druby://127.0.0.1:33876" )
      s.open(url)
    end
  rescue
    puts "接続できないようだ…"
    exit(1)
  end
end

