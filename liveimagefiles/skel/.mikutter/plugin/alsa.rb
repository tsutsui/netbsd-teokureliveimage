# -*- coding: utf-8 -*-
# audioplayコマンドで音を鳴らす

Plugin.create :audioplay do

  audioplay_exist = command_exist?('audioplay')

  defsound :audioplay, "BSD audioplay" do |filename|
    bg_system("audioplay", filename) if FileTest.exist?(filename) and audioplay_exist end

end
