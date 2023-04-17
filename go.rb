#!/usr/bin/env ruby

require 'filesize'
require 'fileutils'
require 'json'
require 'logger'
require 'pp'
require 'pry'
require 'securerandom'
require 'shellwords'
require 'yaml'

# require "./source.rb"

$nas_directory = '/Volumes/storage/videos/youtube'

# `delete_old_files('/path/to/folder', 7)` to delete all files in `/path/to/folder` (including subfolders) that are older than 7 days, and any resulting empty subfolders.
def delete_old_files(path, max_age_days)
  time_threshold = Time.now - (max_age_days * 24 * 60 * 60)
  Dir.glob("#{path}/**/*").select { |f| File.file?(f) && File.mtime(f) < time_threshold }.each do |file|
    FileUtils.rm(file)
  end
  Dir.glob("#{path}/**/").sort_by { |dir| -dir.count("/") }.each do |dir|
    Dir.rmdir(dir) if Dir.empty?(dir)
  end
end

# If the timestamp file doesn't exist, the method will create the file with the current timestamp, 
# and return true. If the file does exist and the timestamp has not exceeded the specified number of 
# days, it will return false. If the timestamp has exceeded the specified number of days, it will 
# update the file with the current timestamp and return true.
# check_time(7, "/path/to/timestamp.txt")

def check_time(days, file_path)
  if File.exist?(file_path)
    timestamp = File.read(file_path).to_i
  else
    timestamp = Time.now.to_i
    File.write(file_path, timestamp)
    return true
  end

  current_time = Time.now.to_i
  if current_time >= timestamp + (days * 86400)
    File.write(file_path, current_time)
    return true
  else
    return false
  end
end


# This video path could work for a channel:
# https://github.com/JordyAlkema/Youtube-DL-Agent.bundle/issues/24

def source_by_year

end

# Relies on playlist_index. Youtube should support.
def playlists_under_source(channel_name, playlist_name, season_no)
	path = File.join($nas_directory, "#{channel_name} [%(channel_id)s]", "Season #{season_no} #{playlist_name}", "S#{season_no}E%(playlist_index)s %(title)s [%(id)s].%(ext)s")

	puts path

	return path
end

def build_command_line_yt(source_path, url)

	# youtube-dl working cmd line
	# cmd = "youtube-dl -o '#{vd}' -f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best' -i --verbose --download-archive downloaded.txt --merge-output-format mkv --add-metadata --embed-thumbnail '#{url}'"

	
	# cmd = "yt-dlp -o '#{vd}' -f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best' --merge-output-format mkv --remux-video mkv --add-metadata --write-info-json --write-thumbnail --no-config --sponsorblock-remove all --restrict-filename '#{url}'"


	cmd = """
		yt-dlp
		-o '#{source_path}'
		-f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/mp4'
		--merge-output-format mkv --remux-video mkv
		--add-metadata --write-info-json --write-thumbnail --convert-thumbnails jpg
		--no-config --sponsorblock-remove all --restrict-filename
		'#{url}'
	""".gsub!(/\n/, ' ')

	puts cmd
	return cmd


	# cmd = [
	# 	'yt-dlp'
	# 	,"-o '#{vd}'"
	# 	,"-f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best'"
	# ] * ' '

	# I had but removed
	# --download-archive downloaded.txt
 	# --add-metadata --embed-thumbnail

 	# these came from here. below are the ones i didn't use
	# yt-dlp config from here: https://old.reddit.com/r/youtubedl/comments/w3se6g/my_ytdlp_config_for_downloading_youtube_channels/
	# -R infinite
	# --fragment-retries infinite
	# --no-part
	# --no-continue
	# --abort-on-error
	# --remove-chapters (?i)intro
	# -S res:480,+size
	# -o %(uploader)s/%(playlist)s/%(playlist_index)s_%(title)s.%(ext)s
end

def find_provider(name, providers_config)
	providers_config.each do |p|
		return p if p['name'] == name
	end
end

# ******
# GO GO
# ******

# system('brew upgrade yt-dlp')

config = YAML.load_file('config.yml')

# config['playlists'].each do |playlist|
#   playlist['playlists'].each_with_index do |inner_playlist, index|
#     index += 1
#     index_str = index.to_s.rjust(2, '0')

#     playlists_under_source(playlist['name'], inner_playlist['name'], index_str)
#   end
# end

# loop over destinations
# loop over providers
config['destinations'].each do |d|
	
	d['providers'].each do |p|
		provider_defaults = {}
		provider_defaults['location'] = d['location']
		provider_defaults.merge!(find_provider(p['name'], config['providers_config']))
		puts "#{p['name']} defaults: #{provider_defaults}"

		p['shows'].each do |show|
			show['sources'].each do |source|
				source_details = provider_defaults.merge(source)
				source_details['show_name'] = show['show_name']
				puts "#{source_details['show_name']} : #{source_details}"
		end
		end
	end
end

