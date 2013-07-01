trimeplay
=========

Airplay server for Roku.

Very experimental at this stage. 

Things that work:
   * Viewing photos (although they don't appear to look very good. I think there's an off-by-one error in the transfer somewhere)
   * Changing the photo you are looking at
   * Stopping photo viewing
   * Viewing videos from the Video app. Only ones without DRM!
   * Starting videos mid-stream
   * Viewing videos from third parties, such as youtube (Again, only without DRM)
   * Pausing and resuming video
   * Stopping videos
   * Scrubbing videos (although this is still slightly buggy)

What does not:
   * Anything with DRM
      * That includes mirroring, surprisingly!
   * Slideshow transitions
   * Sometimes the airplay capability disappears from the network. Not sure why (yet)
   * For some reason the video does not always track correctly on the iDevice. That is, sometimes it doesn't show the video playing when it is (the position does not increase) and play/pause does not start in the right state.
      * Scrubbing fixes this though. It is just the INITIAL state that is wrong.
   * Music

LICENSE:

    Copyright (C) 2013 Matt Lilley

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

Some rants about BrightScript

I'm amazed at the quality of applications people CAN produce using this language. It has a few nice features, but is astonishingly lacking in some really central areas. 
I cannot believe that I can't get the duration of a video out of an roVideo{Player,Screen}. That just beggars belief.
It's a shame that a media-centric device cannot give me more information about MP4 streams in general. I had to write an MP4 decoder from scratch to parse the files and get out the timescale and duration.
I'm disappointed that everything is coerced to a float. It makes integer arithmetic risky at best. I had to write an arbitrary-precision arithmetic module to get the duration of a video, since I was asking the http server for larger and larger ranges of data, and eventually I ended up crossing a bit boundary and getting negative integers.
It's bizarre that str(3) returns " 3" and not "3". I know that there's 3.toStr(), but *only because it is mentioned in an example on the Brightscript Reference Page*. Not because it was documented? The roFloat page (which itself is a challenge to find) says that ifFloat only implements GetFloat and SetFloat. It doesn't actually say what these functions do, though.