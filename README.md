# TedTalk

## Description

TedTalk helps download TED talk video and covert it to a slowed down MP3 with pauses that is useful for English learning

## Installation

TedTalk requires [FFmpeg](http://ffmpeg.org/) and [SoX](http://sox.sourceforge.net/) **with LAME support** [important], as well as [TagLib](http://taglib.github.com/) audio meta-data library installed to the system

    $ gem install ted_talk 


## Usage

	Basic usage: ted_talk desc <option>  - show TED Talk description(s)
	             ted_talk exec <option>  - download and convert a TED Talk video
	             ted_talk delete         - delete cache folder

	For details about <option>, type:
	             ted_talk desc -h
	      or     ted_talk exec -h

	[global options]:
	  --version, -v:   Print version and exit
	     --help, -h:   Show this message

### desc

	ted_talk desc subcommand shows TED Talk descriptions in the newest official RSS
	feed or the URL of a specific talk

	Usage: ted_talk desc <options>
	where <options> are:

	[desc options]:
	  --lang, -l <s>:   Language of description (default: en)
	       --rss, -r:   Show descriptions of the newest talks from TED Talk RSS
	   --url, -u <s>:   URL of a specific TED Talk
	      --help, -h:   Show this message

### exec

	ted_talk exec subcommand download TED Talk video and convert it to an MP3 file
	that is modified in a specified fashion

	Usage: ted_talk exec <options>
	where <options> are:

	[exec options]      
	      --url, -u <s>:   URL of a specific TED Talk
	     --lang, -l <s>:   Language of (bilingual) transcripts (default: en)
	   --outdir, -o <s>:   Directory for file output (default: ./)
	    --speed, -s <f>:   Speed of output file [0.1 - 100] (default: 1.0)
	  --silence, -i <f>:   Length (secondes) of a pause added to each utterance
	                       [0.1 - 120] (default: 0.0)
            --video, -v:   Save not only audio but also the original video	
	         --help, -h:   Show this message
