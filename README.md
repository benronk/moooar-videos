# Moooar-Videos

This is a wrapper around the yt-dlp project. It allows for configuring sources with a config file, how far back to fetch videos, and whether to remove old videos.

## Configuration

`example-config.yml` should be renamed to `config.yml` and setup with your sources, and how you'd like them stored/saved.

`source_seasoned_by_year`, can only appear once per source. It will save vidoes into a subfolder by year. The source should be a channel url.
If a channel started posting videos in 2021 it will make multiple folders to save the videos into:

- Season 2012
- Season 2022
- Season 2023

`source_seasoned_by_name` can appear multiple times per source. It can occur alone under a source, or it can be accompanied by `source_seasoned_by_year`. It saves videos into subfolders indexed by the order they appear in the config file, with the name appended. This was created so these urls are playlists. If there are 3 entires for seasoned by name, with names `Playlist 1`, `Playlist 2`, `Playlist 3` it will make subfolders:

- Season 01 - Playlist 1
- Season 02 - Playlist 2
- Season 03 - Playlist 3

For each provider `days_to_get_and_keep`, `fetch_new_every_days`, `sponsorblock_remove` can be set which operate as defaults for that provider. Each of these can be overwritten by each source.

`days_to_get_and_keep` is either a number or `all`. If all, all videos for the channel/playlist are retreived. If a number is present it will retreive videos posted between now and x days ago.

`fetch_new_every_days` is an integer. Every time a source is fetched a timestamp is created. The next time the script is run it checks to see if is past this value. If so, then it's fetched again.

`sponsorblock_remove` yt-dlp has an option to remove sponsorblocks. `true` to remove them, `false` to keep them.

## Run

`./go.rb`