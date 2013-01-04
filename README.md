# TedTalk

## Description

TedTalk helps download TED talk video and covert it to a slowed down MP3 with pauses that is useful for English learning

## Installation

*TedTalk requires [FFmpeg](http://ffmpeg.org/) with LAME support installed to the system.  Then `gem install`*

    $ gem install ted_talk 


## How to Use

    Usage: ted_talk [options] <source url>
    where: <source url> is something like "http://www.ted.com/talks/xxx_xxx_xxx.html"
    
    [options]:
         --lang, -l <s>:   Language of description and bilingual transcript (default: en)
       --outdir, -o <s>:   Directory for file output (default: ./)
        --speed, -s <f>:   Speed of output file [0.1 - 100] (default: 1.0)
      --silence, -i <i>:   Length (secondes) of a pause added to each utterance [0.1 - 120]
                           (default: 0)
             --desc, -d:   Show descriptions of the talk
          --version, -v:   Print version and exit
             --help, -h:   Show this message
