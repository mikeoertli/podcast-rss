#!/usr/bin/env ruby -wUd
#
# by Kelan Champagne http://yeahrightkeller.com
# with edits by sjschultze
# and advanced metadata handling by lukf
# and features/enhancements by mikeoertli
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
# A script to generate a personal podcast feed, hosted on Dropbox
#
# Inspired by http://hints.macworld.com/article.php?story=20100421153627718
#
# Simply put this, and some .mp3 or .m4a files in a sub-dir under a public folder
# on the web (i.e. server), create your config.txt file in the same directory, and run the
# script. The public_url_base value value is just the URL of the directory that will contain
# the output RSS file. It is assumed that the structure looks like this:
#   <public_url_base>
#      <audio_directory>
#      <image_directory>
#      config.txt
#      podcast.rss (output file)
# 
#
# iTunes recommends artwork in the JPEG or PNG file formats and in the RGB color space
# with a minimum size of 1400 x 1400 pixels and a maximum size of 2048 x 2048 pixels.
# You'll need a *direct* link to the image. This supports artwork per podcast
# feed and per MP3 file (the latter extracts the image from the ID3 tag).
#
# The following lines are a template for your config.txt file; just remove the hashes:
# podcast_title = The Adventures Of Harry Lime
# podcast_description = Orson Welles' radio drama, between 1951 and 1952
# podcast_artwork = http://cl.ly/image/2x3y3A2l1P2S/01.%20Too%20Many%20Crooks.jpg
# public_url_base = https://www.myserver.com/podcast/
# audio_category = Audiobook
# artwork_directory = images
# audio_directory = audio
#
# Notes:
#  * You'll need to re-run it after adding new files to the dir, or you can
#    set up Folder Actions as suggested by the above hint (sample AppleScript
#    in comments at the bottom of this file).
#  * This script uses `ffprobe` to get the source media metadata.
#    You'll need to have the binary installed and on your $PATH (i.e. `which ffprobe` gives
#    a valid result).

require 'date'
require 'erb'
require 'tempfile'
include ERB::Util

# Set up user variables with defaults that can optionally be overridden in the config file
podcast_title = ""
podcast_description = ""
podcast_artwork = ""
public_url_base = ""
item_category = ""
default_item_category = "Podcasts"
audio_directory = "."
artwork_directory = "."
filter_string = ""
counter = 0

# Capture the current working directory so that we can properly handle the various valid combinations of
# audio and artwork directories.
top_level_directory = Dir.pwd
puts "\nCurrent working directory is: " + top_level_directory

# Generated values
date_format = '%a, %d %b %Y %H:%M:%S %z'
printed_date_format = '%d%b%Y_%H%M%S'
current_date_time = DateTime.now.strftime(date_format)
current_url_date_time = DateTime.now.strftime(printed_date_format)

items_content = ""
rss_outfile_path = top_level_directory + "/podcast.rss"
rss_backup_path = top_level_directory + "/bak.podcast.rss-" + current_url_date_time

puts "\nEvaluating Podcast RSS Feed Configuration..."
# Import configuration data
podcast_config_lines = IO.readlines("config.txt")
cleaned_config_entries = podcast_config_lines.select {|i|i.lstrip.start_with?("#") == false} # Ignore comment lines in input
cleaned_config_entries.each {|i|
    fields = i.split("=")[0].gsub(' ', '')
    # non_empty_fields = fields.reject(&:empty?)
    case fields
    when "podcast_title"
        podcast_title = i.split("=")[1].chomp.lstrip
        puts "Creating podcast feed titled: " + podcast_title
    when "podcast_description"
        podcast_description = i.split("=")[1].chomp.lstrip
    when "podcast_artwork"
        podcast_artwork = i.split("=")[1].chomp.lstrip
    when "public_url_base"
        public_url_base = i.split("=")[1].chomp.chomp("/").lstrip
        puts "Found Podcast public URL base: " + public_url_base
    when "audio_category"
        # No matter what, it will first attempt to use the value extracted with ffprobe from the ID3 tags.
        # Then it falls back to the value provided via config, if any, last it would use the default set
        # in the initialization of the default_item_category variable above.
        default_item_category = i.split("=")[1].chomp.lstrip
        puts "Found an audio category/type of: " + default_item_category
    when "audio_directory"
        audio_directory = i.split("=")[1].chomp.lstrip
	if audio_directory == ""
	    audio_directory = "."
	end
        puts "Found custom audio directory of: " + audio_directory
    when "artwork_directory"
        artwork_directory = i.split("=")[1].chomp.lstrip
        if artwork_directory == ""
	        artwork_directory = "."
        end
        puts "Found custom album artwork directory of: " + artwork_directory
    when "filter_string"
        full_filter_string = filter_string = i.split("=")[1]
        
        if full_filter_string == nil
            puts "No filter provided, will include all files."
            full_filter_string = ""
        end
        
        filter_string = full_filter_string.chomp.lstrip
        if filter_string == ""
            puts "No filter enabled"
        else
            puts "Filter enabled for files containing: #{filter_string}"
        end

    else
        puts "Unrecognised config data: " + i
    end
}

puts "\n\n"

append_mode = File.exist?(rss_outfile_path)
trim_to_index = -1
if append_mode
    puts "Found pre-existing RSS file, will append to it at the end and will only include items which the RSS feed does not already contain."
    puts "Backing up previous version of podcast.rss to file: " + rss_backup_path
    FileUtils.copy(rss_outfile_path, rss_backup_path)

    rss_outfile = File.open(rss_outfile_path, "r")

    preserved_lines = 0
    preserved_items = 0
    found_start_of_items = false
    File.foreach(rss_outfile).with_index(1) do |line, index |
        if line.include? "</channel>"
            break
        else
            if line.include? "<item>"
                preserved_items += 1
                found_start_of_items = true
            end

            if found_start_of_items
                preserved_lines += 1
                items_content << line
            end
        end
    end
    rss_outfile.close
    puts "Preserved #{preserved_lines} lines of RSS file which preserves #{preserved_items} podcast item entries."
    counter = preserved_items
else
    puts "No pre-existing RSS feed file, generating a new one..."
end

puts "\n\n"

puts "\nProcessing audio files for podcast feed..."
# Build the items

puts "\n\nFilter String is: #{filter_string}"

Dir.entries(audio_directory).each do |file|
    file_name = File.basename(file)
    skip_reason = "Hidden file"
    # puts "Processing file: #{file_name}"
    next if file =~ /^\./  # ignore invisible files
    # puts "   - Is not hidden..."
        skip_reason = "Unsupported file type (only supports mp3 and m4a)"
    next unless file =~ /\.(mp3|m4a)$/  # only use audio files
    # puts "   - Is an audio file..."

    # next unless "".casecmp("#{filter_string}")
    # puts "   - Filter enabled - Comparing to filter string... #{filter_string}"
        skip_reason = "File name: #{file_name} does not match filter: #{filter_string}"
    next unless file_name.downcase.include? filter_string.downcase
    # puts "   - FILE MATCHES FILTER. File: #{file_name}\n\n"
        skip_reason = "the output RSS file already contains this media"

    relative_file_path = "#{audio_directory}/#{file}"
    puts "Processing file: #{relative_file_path}..."

    #
    # Extract all of the source metadata that we require.
    #

    # Note that other file types have been ruled out at this point, so this else --> mp3 assumption is safe enough
    item_audio_type = "audio/mpeg"
    if file =~ /\.(m4a)$/
        item_audio_type = "audio/x-m4a"
        item_filename = File.basename(file, '.m4a')
    else
        item_filename = File.basename(file, '.mp3')
    end

    if audio_directory == "."
        item_url = "#{public_url_base.gsub("https", "http")}/#{url_encode(file)}"
    else
        item_url = "#{public_url_base.gsub("https", "http")}/#{url_encode(audio_directory)}/#{url_encode(file)}"
    end

    if items_content.index(/#{item_url}/) == nil
        puts "Adding new entry for item: #{item_url}"
        
        full_metadata = `ffprobe 2> /dev/null -show_format "#{relative_file_path}"`

#        puts "\n\n\nFULL METADATA\n"
#        puts "#{full_metadata}"
#        puts "\n\n"

        # If there are double quotes in any of the fields, the comments/description/synopsis, for example - then this falls apart pretty quickly.
        # TODO - add support for escaping problematic characters when parsing fields.
        item_title_number = `echo "#{full_metadata}" | grep TAG:track= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_title_source = `echo "#{full_metadata}" | grep TAG:title= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_text_artist = `echo "#{full_metadata}" | grep TAG:artist= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_text_albumartist = `echo "#{full_metadata}" | grep TAG:albumartist= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_text_description = `echo "#{full_metadata}" | grep TAG:description= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_text_synopsis = `echo "#{full_metadata}" | grep TAG:synopsis= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s # Also known as 'long description'
        item_text_comment = `echo "#{full_metadata}" | grep TAG:comment= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_duration_source = `echo "#{full_metadata}" | grep duration= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        item_category = `echo "#{full_metadata}" | grep genre= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s

        if item_duration_source == ""
            item_duration_source = `echo "#{full_metadata}" | grep duration_time= | cut -d '=' -f 2`.sub(/^.*? = "/, '').sub(/"$/, '').chomp.to_s
        end

#        puts "Duration (sec): #{item_duration_source}"

        # Create the artwork image file
        `ffmpeg -loglevel quiet -i "#{relative_file_path}" -an -vcodec copy -y "#{artwork_directory}/#{item_filename}".jpg`.chomp.to_s

        item_artwork = "#{item_filename}"
        item_artwork << ".jpg"

        puts "Created image file: #{artwork_directory}/#{item_artwork}"

        if artwork_directory == ""
            encoded_relative_art_path = "#{url_encode(item_artwork)}"
        else
            encoded_relative_art_path = "#{url_encode(artwork_directory)}/#{url_encode(item_artwork)}"
        end

        item_artwork_url = "#{public_url_base.gsub("https", "http")}/#{encoded_relative_art_path}"

        item_time_modified = File.mtime(relative_file_path).strftime(date_format)

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

        # Figure out short text. This is the backup text if a long description can't be found, otherwise unused.
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

        # Figure out author - it is either in the artist or albumartist field
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
        item_size_in_bytes = File.size(relative_file_path).to_s
        item_duration = item_duration_source
        item_guid = item_url + url_encode(item_time_modified)

        # <description> is the long description, the "show notes" in a podcast. Use for full description.
        # <item:subtitle> unused
        # <item:summary> is the short 1 (or 2?) lines of info below the title, used for the author
        item_content = <<-HTML
            <item>
                <title>#{item_title}</title>
                <description>#{item_text_long}</description>
                <itunes:subtitle>#{item_author}</itunes:subtitle>
                <itunes:summary>#{item_author}</itunes:summary>
                <enclosure url="#{item_url}" length="#{item_size_in_bytes}" type="#{item_audio_type}" />
                <category>#{item_category}</category>
                <pubDate>#{item_time_modified}</pubDate>
                <guid>#{item_guid}</guid>
                <itunes:author>#{item_author}</itunes:author>
                <itunes:duration>#{item_duration}</itunes:duration>
                <itunes:image href="#{item_artwork_url}"/>
            </item>
HTML

        items_content << item_content

        counter += 1
    else
        puts "\nSkipping adding file #{relative_file_path} to RSS file because: #{skip_reason}."
    end
end

# Build the whole file
content = <<-HTML
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0">
    <channel>
        <title>#{podcast_title}</title>
        <description>#{podcast_description}</description>
        <pubDate>#{current_date_time}</pubDate>
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
