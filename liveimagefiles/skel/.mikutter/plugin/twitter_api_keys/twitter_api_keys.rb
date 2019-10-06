# -*- coding: utf-8 -*-

Plugin.create(:twitter_api_keys) do
  # 下の２行は馬鹿にしか見えない
  consumer_key = 'arQQ6Dmy3CFg6CoKmKb0vVE8B'
  consumer_secret = 'NMiSotti8UEWmaLpsPbTPYUyA8VMNNok6NthlygX4ZCzf2QgFf'
  filter_twitter_default_api_keys do |_ck, _cs|
    [consumer_key, consumer_secret]
  end
end
