#!/bin/zsh
# Usage: make_m4b.sh <out dir>
set -e
out=$1
mkdir -p "$out"
cd "$out"
say -o speech.aiff "This is chapter one of a test audiobook. Testing m4b playback in Amperfy. One, two, three, four, five, six, seven, eight, nine, ten."
# 30+ s of audio, AAC in an m4b container; ffmpeg's ipod muxer writes moov after mdat by default
ffmpeg -loglevel error -y -i speech.aiff -f lavfi -i "sine=frequency=440:duration=30" \
  -filter_complex "[0][1]concat=n=2:v=0:a=1" -c:a aac -b:a 64k -f ipod moov-end.m4b
ffmpeg -loglevel error -y -i moov-end.m4b -c copy -f ipod -movflags +faststart moov-front.m4b
afconvert -f m4bf -d aac speech.aiff afconvert.m4b
for f in *.m4b; do
  printf "%s: " $f
  python3 -I -c '
import struct,sys
d=open(sys.argv[1],"rb").read();i=0;o=[]
while i<len(d):
  s,t=struct.unpack(">I4s",d[i:i+8]);o.append(t.decode());i+=s if s else len(d)
print(" ".join(o))' $f
done
ffprobe -v error -show_entries format=duration -of csv=p=0 moov-end.m4b
