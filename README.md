# podcast-rss
Create an RSS feed from audio files, works great for import into a podcast player like Overcast.

This project was started by by Kelan Champagne http://yeahrightkeller.com
with edits by sjschultze and advanced metadata handling by lukf. I didn't it in
a source repo by Kelan, so for now I'm working in my repo instead of a fork.

This works well for mp3 or m4a files to create a podcast feed from audiobooks
or audio that doesn't come via a public RSS format.

TO RUN
Right now, this script requires being located in the same directory as the
source audio files and requires a config.txt file that configures the
output podcast name, author, artwork, and the URL of the public Dropbox
root directory where you will keep the podcast.rss file.

Once config.txt is setup, just run:
>./podcast_feed_from_dropbox_mp3s.rb
