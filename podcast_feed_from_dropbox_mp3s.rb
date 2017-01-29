#!/usr/bin/env ruby -wKUd
#
# by Kelan Champagne http://yeahrightkeller.com
# with edits by sjschultze
# and advanced metadata handling by lukf
# and stupid things by mikeoertli
#
# ***********************************************************
# ***********************************************************
#              READ THIS BEFORE RUNNING!!!!!!!
# ***********************************************************
# ***********************************************************
# This script and the config.txt should be placed in the directory with the
# audio files, the resulting RSS file will be generated in that same directory.
# ***********************************************************
# ***********************************************************
#
# OERTLI TODO:
# Support unique art work per audio file so that I can have a single feed
# with multiple items in it, for example an audio books feed.
#
#
# A script to generate a personal podcast feed, hosted on Dropbox
#
# Inspired by http://hints.macworld.com/article.php?story=20100421153627718
#
# Simply put this, and some .mp3 or .m4a files in a sub-dir under your Dropbox
# Public folder, create your config.txt file in the same directory, and run the script.  To get
# the public_url_base value, you can right click on a file in that folder
# in Finder, then go to Dropbox > Copy Public Link, and then remove the
# filename.
# iTunes recommends artwork in the JPEG or PNG file formats and in the RGB color space
# with a minimum size of 1400 x 1400 pixels and a maximum size of 2048 x 2048 pixels.
# You'll need a *direct* link to the image, hosted wherever you want. I use cl.ly.
#
# The following lines are a template for your config.txt file; just remove the hashes:
# podcast_title = The Adventures Of Harry Lime
# podcast_description = Orson Welles' radio drama, between 1951 and 1952
# podcast_artwork = http://cl.ly/image/2x3y3A2l1P2S/01.%20Too%20Many%20Crooks.jpg
# public_url_base = https://dl.dropboxusercontent.com/u/55322715/Audio/The%20Adventures%20Of%20Harry%20Lime
# audio_category = Audiobook
#
# Todo:
#  * Parse items' source date, instead of passing through
#  * Do even more sanitising of the metadata.
#
# Notes:
#  * You'll need to re-run it after adding new files to the dir, or you can
#    set up Folder Actions as suggested by the above hint (sample AppleScript
#    in comments at the bottom of this file).
#  * This script uses `ffprobe` to get the source media metadata.
#    You'll need to have the binary installed (in /usr/bin on OS X).

require 'date'
require 'erb'
#require "id3tag"
include ERB::Util

# Set up user variables
podcast_title = ""
podcast_description = ""
podcast_artwork = ""
public_url_base = ""
item_category = "Podcasts"

# Import configuration data
podcast_infos = IO.readlines("config.txt")
podcast_infos.select {|i|i.start_with?('#') == false} # Ignore comment lines in input
podcast_infos.each {|i|
    id = i.split("=")[0].gsub(' ', '')
    case id
    when "podcast_title"
        podcast_title = i.split("=")[1].chomp
    when "podcast_description"
        podcast_description = i.split("=")[1].chomp
    when "podcast_artwork"
        podcast_artwork = i.split("=")[1].chomp
    when "public_url_base"
        public_url_base = i.split("=")[1].chomp
        puts "Found URL base: " + public_url_base
    when "audio_category"
        item_category = i.split("=")[1].chomp
    else
        puts "Unrecognised config data: " + i
    end
}

# Generated values
date_format = '%a, %d %b %Y %H:%M:%S %z'
podcast_pub_date = DateTime.now.strftime(date_format)

# Build the items
items_content = ""
Dir.entries('.').each do |file|
	puts file

    next if file =~ /^\./  # ignore invisible files
    next unless file =~ /\.(mp3|m4a)$/  # only use audio files

    puts "\nAdding audio file: #{file}"

    # Aquiring source metadata
    item_filename = File.basename(file, '').split('.mp3')[0]
    item_title_number = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:track= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_title_source = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:title= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_text_artist = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:artist= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_text_albumartist = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:albumartist= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_text_description = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:description= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_text_synopsis = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:synopsis= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s # Also known as 'long description'
    item_text_comment = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:comment= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_duration_source = `ffprobe 2> /dev/null -show_format "#{file}" | grep duration_time= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_pub_date_source = `ffprobe 2> /dev/null -show_format "#{file}" | grep TAG:date= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
    item_metadata_full = `ffmpeg -loglevel quiet -i "#{file}" -an -vcodec copy -y "#{item_filename}".jpg`.chomp.to_s

    item_artwork = "#{item_filename}"
    item_artwork << ".jpg"
    item_artwork_url = "#{public_url_base.gsub("https", "http")}/#{url_encode(item_artwork)}"


    # Convert number to ordinal
    if item_title_number != ""
        item_title_number += ". "
    end


    # Get correct artist; defaulting to artist
    if item_text_artist == ""
        item_text_artist = item_text_albumartist
    elsif item_text_albumartist.include? item_text_artist
        item_text_artist = item_text_albumartist
    end

    # Figure out short text
    item_text_short_array = [item_text_description, item_text_synopsis]
    item_text_short = item_text_short_array.sort_by(&:length)[0].to_s
    if item_text_short == ""
        item_text_short = item_text_comment
        if item_text_short == ""
            item_text_short = item_text_artist
        end
    end

    # Eliminate duplicates for long text
    item_text_long_array = [item_text_artist, item_text_description, item_text_synopsis, item_text_comment]
    item_text_long_array = item_text_long_array.select {|e|item_text_long_array.grep(Regexp.new(e)).size == 1}
    # Make sure that no component of long text is nil
    item_text_long_array.each { |snil| snil = snil.to_s }
    # Combine long text and add line breaks
    item_text_long = ""
    item_text_long_array.each { |s| item_text_long += s + "\n"}
    item_text_long = item_text_long.chomp()

    # Figure out author
    item_author = item_text_artist
    if item_author == ""
        item_author = item_text_albumartist
    end

    # Figure out title base
    if item_title_source == ""
        item_title_source = item_filename.chomp()
    end

    # Set remaining metadata without logic
    item_title = item_title_number + item_title_source

    # Need to append ?dl=1 to force the download rather than trying to render it in the browser?
    item_url = "#{public_url_base.gsub("https", "http")}/#{url_encode(file)}"
    item_size_in_bytes = File.size(file).to_s
    item_duration = item_duration_source
    item_pub_date = item_pub_date_source
    item_guid = item_url + url_encode(podcast_pub_date)


    item_content = <<-HTML
        <item>
            <title>#{item_title}</title>
            <description>#{item_text_long}</description>
            <itunes:subtitle>#{item_text_short}</itunes:subtitle>
            <itunes:summary>#{item_text_short}</itunes:summary>
            <enclosure url="#{item_url}" length="#{item_size_in_bytes}" type="audio/mpeg" />
            <category>#{item_category}</category>
            <pubDate>#{item_pub_date}</pubDate>
            <guid>#{item_guid}</guid>
            <itunes:author>#{item_author}</itunes:author>
            <itunes:duration>#{item_duration}</itunes:duration>
            <itunes:image href="#{item_artwork_url}"/>
        </item>
HTML

    items_content << item_content
end

# Build the whole file
content = <<-HTML
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">
    <channel>
        <title>#{podcast_title}</title>
        <description>#{podcast_description}</description>
        <pubDate>#{podcast_pub_date}</pubDate>
        <itunes:image href="#{podcast_artwork}"/>
        <itunes:subtitle>#{podcast_description.to_s[0,254]}</itunes:subtitle>
        <itunes:summary>#{podcast_description.to_s[0,3999]}</itunes:summary>
#{items_content}
    </channel>
</rss>
HTML

# write it out
output_file = File.new("podcast.rss", 'w')
re = "[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD\u10000-\u10FFFF]" # Regex for avoiding XML problems
content.gsub(re, "")
output_file.write(content)
output_file.close

# = Sample AppleScript to auto-run this script. =
# This AppleScript also touches the new file so that it's modification
# date (and thus the pubDate in the podcast) are the date/time that you
# put it in the folder.
#
# To install:
# - Open AppleScript Editor and copy-paste the below code (minus #'s)
# - Save the script to "/Library/Scripts/Folder Action Scripts"
# - Control-click the podcast folder, "Services > Folder Actions Setup"
#   and choose your script
#
#on adding folder items to this_folder after receiving added_items
# 	set the_folder to POSIX path of this_folder
# 	set the_folder_quoted to (the quoted form of the_folder as string)
#
# 	repeat with this_item in added_items
# 		set the_item to POSIX path of this_item
# 		set the_item_quoted to (the quoted form of the_item as string)
# 		do shell script "touch " & the_item_quoted
# 	end repeat
#
# 	tell application "Finder"
# 		display dialog "cd " & the_folder_quoted & ";./podcast_feed_from_dropbox_mp3s.rb"
# 		do shell script "cd " & the_folder_quoted & ";./podcast_feed_from_dropbox_mp3s.rb"
# 	end tell
#
# end adding folder items to
