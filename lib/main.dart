import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const PlayerScreen(),
    );
  }
}

class Track {
  final String title;
  final String artist;
  final String path;

  Track(this.title, this.artist, this.path);
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();

  final List<Track> playlist = [
    Track("I Want It All", "Queen", "assets/audio/i_want_it_all.mp3"),
    Track("Under Pressure", "Queen", "assets/audio/under_pressure.mp3"),
  ];

  int currentIndex = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    loadTrack();

    _player.positionStream.listen((p) {
      setState(() => position = p);
    });

    _player.durationStream.listen((d) {
      setState(() => duration = d ?? Duration.zero);
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });
  }

  Future<void> loadTrack() async {
    await _player.setAsset(playlist[currentIndex].path);
  }

  void playPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    setState(() {});
  }

  void next() async {
    currentIndex = (currentIndex + 1) % playlist.length;
    await loadTrack();
    _player.play();
    setState(() {});
  }

  void previous() async {
    currentIndex =
        (currentIndex - 1 + playlist.length) % playlist.length;
    await loadTrack();
    _player.play();
    setState(() {});
  }

  String format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = playlist[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            const Text(
              "PLAYLIST NAME",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            Container(
              height: 400,
              width: 400,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 30),

            // Song title
            Text(
              track.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              track.artist,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Slider
            Row(
              children: [
                Text(format(position)),
                Expanded(
                  child:SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 15, 
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    ),
                    child: Slider(
                      value: position.inSeconds.toDouble(),
                      max: duration.inSeconds.toDouble() > 0
                          ? duration.inSeconds.toDouble()
                          : 1,
                      onChanged: (value) {
                        _player.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                Text(format(duration)),
              ],
            ),

            const SizedBox(height: 20),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 80,
                  color: Colors.white,
                  onPressed: previous,
                ),

                // Big Play/Pause Button
                GestureDetector(
                  onTap: playPause,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    child: Icon(
                      _player.playing ? Icons.pause : Icons.play_arrow,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 80,
                  color: Colors.white,
                  onPressed: next,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}