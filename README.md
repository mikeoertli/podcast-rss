# podcast-rss
Create an RSS feed from audio files, works great for import into a podcast player like Overcast.

This project was started by by Kelan Champagne http://yeahrightkeller.com
with edits by sjschultze and advanced metadata handling by lukf. I didn't see it
in a source repo by Kelan, so for now I'm working in my repo instead of a fork.

This works well for mp3 or m4a files to create a podcast feed from audiobooks
or audio that doesn't come via a public RSS format.

###NOTICE ABOUT DROPBOX PUBLIC FOLDERS
Thanks to new Dropbox policies going into effect on March 15, 2017, public folders are going away. I am planning to make sure this script supports other cloud providers, likely focusing on Google Drive first. I expect it should work as long as you have the files downloaded to a local folder and can find a base URL that is valid.


###TO RUN
Right now, this script requires being located in the same directory as the
source audio files and requires a config.txt file that configures the
output podcast name, author, artwork, and the URL of the public Dropbox
root directory where you will keep the podcast.rss file.

Once config.txt is setup, just run:
>./podcast_feed_from_dropbox_mp3s.rb

## Example config.txt
The following lines are a template for your config.txt file; just remove the hashes:
>podcast_title = The Adventures Of Harry Lime
>podcast_description = Orson Welles' radio drama, between 1951 and 1952
>podcast_artwork = http://cl.ly/image/2x3y3A2l1P2S/01.%20Too%20Many%20Crooks.jpg
>public_url_base = https://dl.dropboxusercontent.com/u/1234567/Audio/
