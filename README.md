# podcast-rss
Create an RSS feed from audio files, works great for import into a podcast
player like Overcast.

This project was started by by Kelan Champagne http://yeahrightkeller.com
with edits by sjschultze and advanced metadata handling by lukf. I didn't see it
in a source repo by Kelan, so for now I'm working in my repo instead of a fork.

This works well for mp3 or m4a files to create a podcast feed from audiobooks
or audio that doesn't come via a public RSS format.

### NOTICE ABOUT DROPBOX PUBLIC FOLDERS
Thanks to new Dropbox policies going into effect on March 15, 2017, public
folders are going away. For foreseeable future, this script assumes you have
somewhere to host files, it is agnostic as to that location.

### HOSTING FILES
I recommend a Linode instance, they start at $5/month. You can host it yourself
very easily too, but keep in mind that the root directory you use might need
to be publicly visible (for Overcast it does - the Overcast server needs to be
able to query the directory you put these files in.)


### TO RUN
Right now, this script requires being located in the same directory as the
source audio files and requires a config.txt file that configures the
output podcast name, author, artwork, and the URL of the public Dropbox
root directory where you will keep the podcast.rss file. These can be symlinks 
though.

The filter_string is an optoinal entry (can be blank after the "=" or you can omit the
filter_string entry in config.txt entirely) that supports filtering which files are included.
It is a crude way to support creating a podcast feed for only certain audio files, for example,
use "Harry Potter" and you will get any audio file which has "Harry Potter" (case-insensitive) 
in the file name (not metadata). Note that the value *can* include spaces.

Once config.txt is setup, just run:
>./create_podcast_feed.rb

## Example config.txt
```
podcast_title = My Podcast
podcast_description = My very interesting podcast
podcast_artwork = http://www.wilwheaton.net/mt/archives/evil_monkey.gif
public_url_base = http://123.456.789.0/audio/
artwork_directory = images
audio_directory = audio
filter_string = Harry Potter
```
