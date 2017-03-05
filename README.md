# podcast-rss
Create an RSS feed from audio files, works great for import into a podcast player like Overcast.

This project was started by by Kelan Champagne http://yeahrightkeller.com
with edits by sjschultze and advanced metadata handling by lukf. I didn't see it
in a source repo by Kelan, so for now I'm working in my repo instead of a fork.

This works well for mp3 or m4a files to create a podcast feed from audiobooks
or audio that doesn't come via a public RSS format.

###NOTICE ABOUT DROPBOX PUBLIC FOLDERS
Thanks to new Dropbox policies going into effect on March 15, 2017, public folders are going away. I am planning to make sure this script supports other cloud providers, though it seems Google Drive won't work because they have an algorithm to create the URLs and at first glance their API doesn't support what I'd need. Also, after reading some more on the Dropbox stuff, it might actually still work for this because all we need is effectively the equivalent of YouTube's "unlisted"
or Google Drive "Anyone with the link" access.


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
