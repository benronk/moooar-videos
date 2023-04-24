#!/usr/bin/env ruby

require 'date'
require 'filesize'
require 'fileutils'
require 'json'
require 'logger'
require 'pp'
require 'pry'
require 'securerandom'
require 'shellwords'
require 'yaml'


def format_index_as_season_number(index)
	index += 1
  index.to_s.rjust(2, '0')
end

def format_dateafter(var)
	if var == 'all'
		""
	elsif var.is_a?(Integer)
		"--dateafter #{(Date.today - var).strftime("%Y%m%d")}"
	end
end

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

def time_for_getting_show?(days, file_path)
	file_path = File.join(file_path, "timestamp.txt")

	if !File.exist?(file_path)
		return true
	else 
		timestamp = File.read(file_path).to_i
		current_time = Time.now.to_i
		if current_time >= timestamp + (days * 86400)
	    return true
	  else 
	  	return false
	  end
  end
end

def show_successfully_got(file_path)
	file_path = File.join(file_path, "timestamp.txt")

	timestamp = Time.now.to_i
	File.write(file_path, timestamp)
end


# This video path could work for a channel:
# https://github.com/JordyAlkema/Youtube-DL-Agent.bundle/issues/24

def source_seasoned_by_year(deets)
	deets['dateafter'] = format_dateafter(deets['days_to_get_and_keep'])
	deets['options'] = "--playlist-reverse"
	deets['path'] = File.join(deets['location'], deets['show_name'])
	deets['full_path'] = File.join(deets['path'], "Season %(upload_date>%Y)s", "S%(upload_date>%Y)sE%(playlist_autonumber)s %(title)s.%(ext)s")

	build_yt_dlp_cmd(deets)
end

def sources_seasoned_by_name(deets)
	deets['dateafter'] = format_dateafter(deets['days_to_get_and_keep'])
	deets['path'] = File.join(deets['location'], deets['show_name'], "Season #{deets['season_index']} - #{deets['season_name']}")
	deets['full_path'] = File.join(deets['path'], "S#{deets['season_index']}E%(playlist_autonumber)s %(title)s.%(ext)s")

	build_yt_dlp_cmd(deets)
end

# Relies on playlist_index. Youtube should support.
# def playlists_under_source(location, channel_name, playlist_name, season_no)
# 	path = File.join(location, "#{channel_name} [%(channel_id)s]", "Season #{season_no} #{playlist_name}", "S#{season_no}E%(playlist_index)s %(title)s [%(id)s].%(ext)s")

# 	puts path

# 	return path
# end

def build_yt_dlp_cmd(deets)

	# youtube-dl working cmd line
	# cmd = "youtube-dl -o '#{vd}' -f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best' -i --verbose --download-archive downloaded.txt --merge-output-format mkv --add-metadata --embed-thumbnail '#{url}'"

	
	# cmd = "yt-dlp -o '#{vd}' -f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best' --merge-output-format mkv --remux-video mkv --add-metadata --write-info-json --write-thumbnail --no-config --sponsorblock-remove all --restrict-filename '#{url}'"

	puts """
*************
Source details: #{deets['show_name']}
#{deets}
*************
		"""

	if !time_for_getting_show?(deets['fetch_new_every_days'], deets['path'])
		puts """
*************
NOT time for getting! Skipping!
*************
			"""
		return
	end

	cmd = """
yt-dlp \
-o '#{deets['full_path']}' \
--download-archive '#{File.join(deets['path'], 'downloaded.txt')}' \
#{deets['dateafter']} \
#{deets['options']} \
-f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/mp4' \
--format-sort lang:en-us \
--merge-output-format mkv --remux-video mkv \
--add-metadata --write-info-json --write-thumbnail --convert-thumbnails jpg \
--no-config --sponsorblock-remove all --restrict-filename \
'#{deets['url']}' \
	"""
	

	puts cmd
	system cmd

	show_successfully_got(deets['path'])

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

def find_provider(provider_name, providers_config)
	providers_config.each do |p|
		return p if p['provider_name'] == provider_name
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
		if !File.exist?(d['location'])
			puts "Path #{d['location']} is unreachable" 
			return
		end

		provider_defaults = {}
		provider_defaults['location'] = d['location']
		provider_defaults.merge!(find_provider(p['provider_name'], config['providers_config']))
		puts "#{p['provider_name']} defaults: #{provider_defaults}"

		p['shows'].each do |show|
			# source_seasoned_by_year
			if show['source_seasoned_by_year']
				source_details = provider_defaults.merge(show['source_seasoned_by_year'])
				source_details['show_name'] = show['show_name']
				source_seasoned_by_year(source_details)
			end

			# sources_seasoned_by_name
			if show['sources_seasoned_by_name']
				show['sources_seasoned_by_name'].each_with_index do |source, i|
					source_details = provider_defaults.merge(source)
					source_details['show_name'] = show['show_name']
					source_details['season_index'] = format_index_as_season_number(i)
					sources_seasoned_by_name(source_details)
				end
			end
		end
	end
end

