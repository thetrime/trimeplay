trimeplay
=========

Airplay server for Roku.

Somewhat experimental at this stage. Probably usable if you're willing to ignore a few problems

Things that work:
   * Viewing photos
   * Changing the photo you are looking at
   * Stopping photo viewing
   * Viewing videos from the Video app. Only ones without DRM!
   * Starting videos mid-stream
   * Viewing videos from third parties, such as youtube (Again, only without DRM)
   * Pausing and resuming video
   * Stopping videos

What does not (because either it never will or I have no interest in doing it)
   * Anything with DRM
      * That includes mirroring, surprisingly! That's a shame really: I might try and get mirroring off the never-to-be-done list, but it seems unlikely to happen :(
   * Slideshow transitions (Don't care)
   * Music (not really interested. The protocol is very complicated, which is surprising given how simple video is?)

What doesn't work *but should* (ie, bugs)
   * Sometimes the airplay capability disappears from the network. Not sure why (yet)
   * Sockets are not correctly cleaned up. See the fixme in trimeplay.brs
   * the screensaver will still come on if you're looking at a photo. I don't know if this is a bug or a feature?

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
   * I cannot believe that I can't get the duration of a video out of an roVideo{Player,Screen}. That just beggars belief.
   * It's a shame that a media-centric device cannot give me more information about MP4 streams in general. I had to write an MP4 decoder from scratch to parse the files and get out the timescale and duration.
   * I'm disappointed that everything is coerced to a float. It makes integer arithmetic risky at best. I had to write an arbitrary-precision arithmetic module to get the duration of a video, since I was asking the http server for larger and larger ranges of data, and eventually I ended up crossing a bit boundary and getting negative integers. Yes, I had to write my own functions to ADD TWO NUMBERS TOGETHER RELIABLY. Wow. Just, wow.
   * It's bizarre that str(3) returns " 3" and not "3". I know that there's 3.toStr(), but *only because it is mentioned in an example on the Brightscript Reference Page*. Not because it was documented. The roFloat page (which itself is a challenge to find) says that ifFloat only implements GetFloat and SetFloat. It doesn't actually say what these functions do, though.
   * There is no easy way to find out the status of a socket. I don't know why this is so hard: There are a million functions you have to call to check the statuses, and sockets seem to never return true to isConnected(), even when they clearly are.
   * There's also no easy way to find out that your connection has been dropped. I still can't figure out if this is even possible!
   * I misspelled invalid as invlaid once, and validation succeeded, but the *entire system crashes* when it executes it. 