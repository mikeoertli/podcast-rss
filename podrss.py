#!/usr/bin/python
"""
Create an RSS feed from the files in a Dropbox folder.
THIS IS IN BETA
Lots about this could use fixing, heavily depending on global vars, inconsistent
variable naming, etc.
"""

import sys
import getopt
import dropbox
import os
import glob
import ConfigParser
import ffmpy
import FFProbe
import importlib
import subprocess as sp


# By default, work in the existing directory, assume this script and the
# audio files area ll in it together.
defaultBookDir = '/Users/moertli/Dropbox/Apps/PodRss'
bookDir = ''

# Config file includes album artwork, podcast name, etc. See README for examples.
defaultConfigFile = "podrss.cfg"
configFile = ''

# The file containing your personal Dropbox API token, this has to be generated
# and should never be shared. See the README for more information.
defaultDropboxTokenFile = "dropbox.key"
dropboxTokenFile = ''
dropboxToken = ''

# Output RSS file to generate
defaultOutputFile = "podcast.rss"
outputFile = ''

# Dictionary of the audio files and their share URLs
urlDictionary = {}

# Dictionary of the audio files and their album art
artDictionary = {}

# List of the currently supported audio formats
supportedFormats = ["mp3", "m4a"]

# Podcast artwork (for the main feed, per-episode art is also supported)
feedArtwork = ''

# Podcast Title
feedTitle = ''

# Description
feedDescription = ''

# Used in debug/print messages, automate this?
scriptName = "podrss.py"


def main(argv):

   print os.environ['PATH']
   try:
      opts, args = getopt.getopt(argv,"hc:d:t:f:",["configFile=","bookDir=","dropboxToken=","dropboxTokenFile="])
   except getopt.GetoptError:
      print scriptName + ' -config <configFile> -dir <bookDir> -token <dropboxToken> -tokenFile <dropboxTokenFile>'
      sys.exit(2)

   # Parse input arguments, setup paths, tokens, etc. based on user input/defaults
   initializeUserConfiguration(opts, args)

   verifyValidToken()
   dbx = setupDropboxApi()

   audioFileList = getAudioFiles(bookDir)
   #artDictionary = createAlbumArtwork(audioFileList, baseDir)
   urlDictionary = createShareUrlsForFiles(audioFileList)
   createPodcassRssFeed(audioFileList, outputFile)




def initializeUserConfiguration(opts, args):
   global configFile
   global bookDir
   global dropboxToken
   global dropboxTokenFile
   global dropboxToken
   global outputFile

   for opt, arg in opts:
      if opt == '-h':
         print scriptName + ' -config <configFile> -dir <bookDir> -token <dropboxToken> -tokenFile <dropboxTokenFile>'
         sys.exit()
      elif opt in ("-c", "--config"):
         configFile = arg
         print "User specified config file: " + configFile
      elif opt in ("-d", "--dir"):
         bookDir = arg
         print "User specified book directory: " + bookDir
      elif opt in ("-t", "--token"):
         dropboxToken = arg
         print "User specified Dropbox token: " + dropboxToken
      elif (opt in ("-f", "--dropboxTokenFile") and dropboxToken == ''):
         dropboxTokenFile = arg
         dropboxToken = getDropboxTokenFromFile(dropboxTokenFile)
         print "User specified Dropbox token file: " + dropboxTokenFile
      elif opt in ("-o", "--out","--outFile"):
         outputFile = arg
         print "User specified RSS output file: " + outputFile

   # Use defaults if the values aren't specified
   if not configFile:
      configFile = defaultConfigFile
   if not bookDir:
      bookDir = defaultBookDir
   if not outputFile:
      outputFile = defaultOutputFile

   parseConfigFile(configFile)


# Parse the configuration file, would be good to make this more dynamic
# currently hard coded sections and section indexes
def parseConfigFile(configFile):
   sections = ("Podcast", "Dropbox")
   configDict = {}
   dropboxDict = {}
   configParser = ConfigParser.ConfigParser()
   configParser.read(configFile)

   dropboxDict = getConfigSectionMap(configParser, sections[1])
   configDict = getConfigSectionMap(configParser, sections[0])

   global dropboxToken
   dropboxToken = dropboxDict["token"]
   global feedTitle
   feedTitle = configDict["podcast_title"]
   global feedDescription
   feedDescription = configDict["podcast_description"]
   global feedArtwork
   feedArtwork = configDict["podcast_artwork"]


# Read a section of the config file
def getConfigSectionMap(configParser, section):
   configDict = {}
   for option in configParser.options(section):
      configDict[option] = configParser.get(section, option)

   return configDict



# Get the audio files in the specified base directory
def getAudioFiles(baseDir):
   audioFiles = []
   for file in os.listdir(baseDir):
      if file.endswith(tuple(supportedFormats)):
         audioFiles.append(file)
         print("Found audio file: " + os.path.join(baseDir, file))

   return audioFiles




# Create the per-episode podcast artwork
def createPodcassRssFeed(fileList, rssFile):
   # Setup the ffmpeg and ffprobe commands for the platform
   if os.name is 'nt':
      # Windows
      ffmpegBin = "ffmpeg.exe"
   elif os.name is 'posix':
      # Mac or Linux
      ffmpegBin = "ffmpeg"
   else:
      print "ERROR: Unable to determine operating system type, can't use ffmpeg."
      sys.exit(2)

   for file in fileList:
      itemTrackName = os.path.splitext(os.path.basename(file))[0]
      itemArtName = itemTrackName + ".jpg"

      # importlib.import_module('lib.ffprobe', FFProbe)
      itemMetadata = FFProbe(file)
      print itemMetadata.streams

      # itemTitleNumber
      # itemTitleSource
      # itemArtist
      # itemAlbumArtist
      # itemDescription
      # itemLongDescription
      # itemComment
      # itemDuration
      # itemArtUrl





######### -- DROPBOX API METHODS -- ###########

# Make sure the provided token is valid, if not we can't do anything
def verifyValidToken():
   # Check for an access token
   if (len(dropboxToken) == 0):
      sys.exit("ERROR: Looks like you haven't configured a Dropbox API token, "
         "the length of the token is zero.")

# Setup the Dropbox API stuff, store reference to it
def setupDropboxApi():
   global dbx
   # Create an instance of a Dropbox class, which can make requests to the API.
   print("Creating a Dropbox object...")
   dbx = dropbox.Dropbox(dropboxToken)

   # Check that the access token is valid
   try:
      dbx.users_get_current_account()
   except AuthError as err:
      sys.exit("ERROR: Invalid access token; try re-generating an "
         "access token from the app console on the web.")

   return dbx


# For all of the files in the directory, get or create a shared link.
# Use the default settings which are public (public is required for this)
def createShareUrlsForFiles(fileList):
   global dbx
   linkDict = {}
   for file in fileList:
      fileName = "/" + os.path.basename(file)
      print "File name is: " + fileName
      linkDict[fileName] = dbx.sharing_create_shared_link(fileName).url
      print linkDict[fileName]
   return linkDict


# Get the dropbox token from the specified file
def getDropboxTokenFromFile(dropboxTokenFile):
   tokenDict = {}
   configParser = ConfigParser.ConfigParser()
   configParser.read(dropboxTokenFile)
   tokenDict['token'] = Config.get("Dropbox","token")
   return tokenDict["token"]


######### -- END OF THE DROPBOX API METHODS -- ###########

if __name__ == "__main__":
   main(sys.argv[1:])
