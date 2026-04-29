import 'dart:ui';
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

  bool _showVolume = false;
  double _volume = 1.0;

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

    _player.setVolume(_volume);
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
      body: GestureDetector(
        onLongPressStart: (_) {
          setState(() => _showVolume = true);
        },
        onLongPressMoveUpdate: (details) {
          final screenHeight = MediaQuery.of(context).size.height;

          double newVolume = 1 - (details.localPosition.dy / screenHeight);
          newVolume = newVolume.clamp(0.0, 1.0);

          _player.setVolume(newVolume);

          setState(() => _volume = newVolume);
        },
        onLongPressEnd: (_) {
          setState(() => _showVolume = false);
        },
        child: Stack(
          children: [
            _buildMainUI(track),
            if (_showVolume) _buildVolumeOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainUI(Track track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          const Text(
            "PLAYLIST NAME",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Gray square
          Container(
            height: 400,
            width: 400,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          const SizedBox(height: 30),

          // Title + Car button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.artist,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Slider
          Row(
            children: [
              Text(format(position)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 15,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 17),
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
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 80,
                onPressed: previous,
              ),
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
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 80,
                onPressed: next,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeOverlay() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 150,
            height: 800,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 30),

                Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 40
                )
                ,
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 40,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 40),
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (value) {
                          _player.setVolume(value);
                          setState(() => _volume = value);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(
                  Icons.volume_off,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}