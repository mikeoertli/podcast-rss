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
use "Super Adventure Series" and you will get any audio file which has "Super Adventure Series" 
(case-insensitive) in the file name (not metadata). Note that the value *can* include spaces.

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
filter_string = Super Adventure Series
```

## ID3 Field Mapping
Unforunately, ID3 tags are really inconsistent. Audiobooks don't populate fields in a standardized way, 
so there is some guessing when it comes to populating the podcast item fields.

The `ffprobe` command that is used to populate the RSS item entry is:
```
ffprobe 2> /dev/null -show_format <file.mp3|.m4a>
```

I only use this with Overcast, so keep in mind that the field mappings will possibly differ for other players.
So you might need fields mapped slightly differently.

#### Author
The author is usually in the `artist` or `albumartist` ID3 tag field, this is used as the `<itunes:summary>`
value in the output RSS file. The actual subtitles are too inconsistent in both IF and WHERE they are present
in the ID3 tag to use the actual subtitle, so the Author is used.

#### Long Description in "Show Notes"
The long description, i.e. full synopsys of the story, needs to go where the show notes go for podcasts.
This is the `<description>` field in the RSS entry. This information is inconsistent in the ID3 tags, so
we attempt to find it in the `description`, `synopsys`, and `comment` fields of the ID3 tag. Even then,
it isn't reliably found.

#### Subtitle
The subtitle field is not used directly, though the subtitle from the ID3 tag is in the list of things that 
can be used when populating the long description in the RSS item depending what else can be found.
