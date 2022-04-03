# -*- coding: utf-8 -*-

require 'base64'

Plugin.create(:twitter_api_keys) do
  # 下の２行は馬鹿にしか見えない
  consumer_key = Base64.decode64('YXJRUTZEbXkzQ0ZnNkNvS21LYjB2VkU4Qg==')
  consumer_secret = Base64.decode64('Tk1pU290dGk4VUVXbWFMcHNQYlRQWVV5QThWTU5Ob2s2TnRobHlnWDRaQ3pmMlFnRmY=')
  filter_twitter_default_api_keys do |_ck, _cs|
    [consumer_key, consumer_secret]
  end
end
