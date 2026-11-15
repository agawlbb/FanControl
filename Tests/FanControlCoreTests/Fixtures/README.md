The generated-tone.mp3 fixture is a generated 440 Hz sine tone, not an imported
recording. It is MPEG-1 Layer III, 128 kbps CBR, 44.1 kHz, two channels, with an
ID3v2.3 tag. These are the encoding characteristics of the user-reported MP3.
The supplied recording is kept in the ignored build/audio-investigation folder
and is never committed or uploaded by these tests.

Generated inside the development container with ffmpeg:

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:sample_rate=44100:duration=0.25' \
  -ac 2 -c:a libmp3lame -b:a 128k -write_xing 0 -id3v2_version 3 \
  -map_metadata -1 -metadata title='Generated test tone' generated-tone.mp3
```

Native decoder tests inspect/initialize audio only and never call play().
