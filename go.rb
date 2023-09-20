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

RUNTIME = (Time.now - 60).to_i

$dev_mode = false
$healthcheck_uuid
$summary

# val: start, end, fail
def healthcheck(var, msg = '')
	case var
	when 'start'
		system "curl -fsS -m 10 --retry 5 https://hc-ping.com/#{$healthcheck_uuid}/start" unless $dev_mode
	when 'end'
		puts msg
		system "curl -fsS -m 10 --retry 5 --data-raw \"#{msg}\" https://hc-ping.com/#{$healthcheck_uuid}" unless $dev_mode
	when 'fail'
		puts msg
		system "curl -fsS -m 10 --retry 5 --data-raw \"#{msg}\" https://hc-ping.com/#{$healthcheck_uuid}/fail" unless $dev_mode
	else
	end
end

# This turns 1 into 01 just for prettiness
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

def format_sponsorblock(var)
	" --sponsorblock-remove all" if var
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
	return true if $dev_mode
	file_path = File.join(file_path, "timestamp.txt")

	if !File.exist?(file_path)
		return true
	else 
		timestamp = File.read(file_path).to_i
		if RUNTIME >= timestamp + (days * 86400)
	    return true
	  else 
	  	return false
	  end
  end
end

def show_got(file_path)
	file_path = File.join(file_path, "timestamp.txt")

	File.write(file_path, RUNTIME)
end

def run_ytdlp_cmd(deets, url, outputfile)
	cmd = """
yt-dlp \
#{deets['user_and_password']} \
-o '#{deets['full_path']}' \
--download-archive '#{File.join(deets['path'], 'downloaded.txt')}' \
#{deets['dateafter']} \
#{deets['options']} \
#{deets['sponsorblock']} \
-f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/mp4' \
--format-sort lang:en-us \
--merge-output-format mkv --remux-video mkv \
--add-metadata --write-info-json --write-thumbnail --convert-thumbnails jpg \
--no-config --restrict-filename --cookies-from-browser chrome \
'#{url}' \
| tee '#{outputfile}'
	"""
	
	puts cmd
	system cmd unless $dev_mode
end



# --cookies-from-browser chrome

# Download Udemy course keeping each chapter in separate directory under MyVideos directory in your home
# $ yt-dlp -u user -p password -P "~/MyVideos" -o "%(playlist)s/%(chapter_number)s - %(chapter)s/%(title)s.%(ext)s" "https://www.udemy.com/java-tutorial"

# Download entire series season keeping each series and each season in separate directory under C:/MyVideos
# $ yt-dlp -P "C:/MyVideos" -o "%(series)s/%(season_number)s - %(season)s/%(episode_number)s - %(episode)s.%(ext)s" "https://videomore.ru/kino_v_detalayah/5_sezon/367617"



# Available for the video that belongs to some logical chapter or section:

# chapter (string): Name or title of the chapter the video belongs to
# chapter_number (numeric): Number of the chapter the video belongs to
# chapter_id (string): Id of the chapter the video belongs to
# Available for the video that is an episode of some series or programme:

# series (string): Title of the series or programme the video episode belongs to
# season (string): Title of the season the video episode belongs to
# season_number (numeric): Number of the season the video episode belongs to
# season_id (string): Id of the season the video episode belongs to
# episode (string): Title of the video episode
# episode_number (numeric): Number of the video episode within a season
# episode_id (string): Id of the video episode

def source_seasoned_by_season(deets)
	# deets['user_and_password'] = "-u #{deets['user']} -p #{deets['password']}"
	deets['sponsorblock'] = format_sponsorblock(deets['sponsorblock_remove'])
	deets['path'] = File.join(deets['location'], deets['show_name'])
	deets['full_path'] = File.join(deets['path'], "Season %(season_number)s", "%(series)s S%(season_number)sE%(episode_number)s %(title)s.%(ext)s")

	yt_dlp(deets)
end

# This video path could work for a channel:
# https://github.com/JordyAlkema/Youtube-DL-Agent.bundle/issues/24

def source_seasoned_by_year(deets)
	deets['dateafter'] = format_dateafter(deets['days_to_get_and_keep'])
	deets['options'] = "--playlist-reverse"
	deets['sponsorblock'] = format_sponsorblock(deets['sponsorblock_remove'])
	deets['path'] = File.join(deets['location'], deets['show_name'])
	deets['full_path'] = File.join(deets['path'], "Season %(upload_date>%Y)s", "S%(upload_date>%Y)sE%(playlist_autonumber)s %(title)s.%(ext)s")

	yt_dlp(deets)
end

def sources_seasoned_by_name(deets)
	deets['dateafter'] = format_dateafter(deets['days_to_get_and_keep'])
	deets['sponsorblock'] = format_sponsorblock(deets['sponsorblock_remove'])
	deets['path'] = File.join(deets['location'], deets['show_name'], "Season #{deets['season_index']} - #{deets['season_name']}")
	deets['full_path'] = File.join(deets['path'], "S#{deets['season_index']}E%(playlist_autonumber)s %(title)s.%(ext)s")

	yt_dlp(deets)
end

def yt_dlp(deets)

	# youtube-dl working cmd line
	# cmd = "youtube-dl -o '#{vd}' -f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best' -i --verbose --download-archive downloaded.txt --merge-output-format mkv --add-metadata --embed-thumbnail '#{url}'"

	
	# cmd = "yt-dlp -o '#{vd}' -f 'bestvideo[ext=mp4][height<=?720]+bestaudio[ext=m4a]/best[ext=mp4][height<=?720]/best' --merge-output-format mkv --remux-video mkv --add-metadata --write-info-json --write-thumbnail --no-config --sponsorblock-remove all --restrict-filename '#{url}'"

# 	puts """
# *************
# Source details: #{deets['show_name']}
# #{deets}
# *************
# 		"""

	if time_for_getting_show?(deets['fetch_new_every_days'], deets['path'])
		$summary[:downloaded_count] += 1
		$summary[:downloaded] << "#{deets['show_name']} #{deets['season_name']}"
	else
		$summary[:skipped_count] += 1
		$summary[:skipped] << "#{deets['show_name']} #{deets['season_name']}"
		return
	end

	ytdlp_output_file = File.join('logs', "#{deets['show_name']}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt")
	puts ytdlp_output_file

	if deets['urls']
		deets['urls'].each do |url|
			run_ytdlp_cmd(deets, url, ytdlp_output_file)
		end
	else
		run_ytdlp_cmd(deets, deets['url'], ytdlp_output_file)
	end 
	
	return if $dev_mode

	show_got(deets['path'])

	# load ytdlp_output_file, parse and save video id file
	# so old videos can be ignored
	if (deets['provider_name'] == 'youtube')
		input = File.read(ytdlp_output_file)
		output = input.scan(/\[(\w+)\] Extracting URL: https:\/\/www\.youtube\.com\/watch\?v=(\S+)/).map { |match| "#{match[0]} #{match[1]}" }
		
		File.open(File.join('logs', "#{deets['show_name']}_video_ids_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt"), 'w') do |file|
		  file.puts(output) if !output.empty?
		end
	end


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

begin
	config = YAML.load_file('config.yml')
	
	$healthcheck_uuid = config['healthcheck_uuid']
	$dev_mode = config['dev_mode']
	puts "dev mode ON!" if $dev_mode

	healthcheck('start')

	system "brew upgrade yt-dlp" unless $dev_mode

	FileUtils.mkdir_p('logs')

	# loop over destinations
	# loop over providers
	config['destinations'].each do |d|
		
		d['providers'].each do |p|
			if !File.exist?(d['location'])
				message = "Path #{d['location']} is unreachable"
				healthcheck('fail', message)
				return
			end

			$summary = {downloaded_count: 0, downloaded: [], skipped_count: 0, skipped: []}

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

				# source_seasoned_by_season
				if show['source_seasoned_by_season']
					source_details = provider_defaults.merge(show['source_seasoned_by_season'])
					source_details['show_name'] = show['show_name']
					source_seasoned_by_season(source_details)
				end
			end
		end

		# skipped_formatted
		summary = """
Downloaded sources: #{$summary[:downloaded_count]}
#{$summary[:downloaded].map { |item| "- #{item}" }.join("\n")}
Skipped sources: #{$summary[:skipped_count]}
#{$summary[:skipped].map { |item| "- #{item}" }.join("\n")}
		"""
		
		# system "curl -fsS -m 10 --retry 5 https://hc-ping.com/#{config['healthcheck_uuid']}"
		# summary = "go.rb finished successfully"
		healthcheck('end', summary)		

	rescue => e
		message = "An error occurred: #{e.message}"
		healthcheck(fail, message)
	end
end

