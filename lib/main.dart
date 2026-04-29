import 'dart:async';
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

class Clip {
  final String trackPath;
  final String clipName;
  final Duration start;
  final Duration end;

  Clip(this.clipName, this.trackPath, this.start, this.end);
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

  final List<Clip> clips = [];

  int currentIndex = 0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool _showVolume = false;
  double _volume = 1.0;

  Duration _clipStart = Duration.zero;
  Duration _clipEnd = const Duration(seconds: 10);
  String _clipName = "";

  Timer? _clipTimer;

  final TextEditingController nameController = TextEditingController();

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
    _clipTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _openClipDialog() {
    showDialog(
      context: context,
      builder: (context) {
        Duration tempStart = _clipStart;
        Duration tempEnd = _clipEnd;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxSeconds = duration.inSeconds.toDouble() > 0
                ? duration.inSeconds.toDouble()
                : 1.0;

            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text("Create Clip"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Enter clip title"),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: "Clip name",
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text("Start: ${format(tempStart)}"),
                  Slider(
                    value: tempStart.inSeconds
                        .toDouble()
                        .clamp(0, maxSeconds),
                    max: maxSeconds,
                    onChanged: (v) {
                      setDialogState(() {
                        final newStart = Duration(seconds: v.toInt());

                        if (newStart >= tempEnd) {
                          tempStart = tempEnd - const Duration(seconds: 1);
                          if (tempStart < Duration.zero) {
                            tempStart = Duration.zero;
                          }
                        } else {
                          tempStart = newStart;
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  Text("End: ${format(tempEnd)}"),
                  Slider(
                    value: tempEnd.inSeconds
                        .toDouble()
                        .clamp(0, maxSeconds),
                    max: maxSeconds,
                    onChanged: (v) {
                      setDialogState(() {
                        final newEnd = Duration(seconds: v.toInt());

                        if (newEnd <= tempStart) {
                          tempEnd = tempStart + const Duration(seconds: 1);

                          if (tempEnd > duration) {
                            tempEnd = duration;
                          }
                        } else {
                          tempEnd = newEnd;
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tempEnd <= tempStart) return;

                    final String name = nameController.text.trim();

                    setState(() {
                      _clipStart = tempStart;
                      _clipEnd = tempEnd;
                      _clipName = name;
                    });

                    _saveClip();
                    Navigator.pop(context);
                  },
                  child: const Text("Save Clip"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _saveClip() {
    if (_clipEnd <= _clipStart) return;

    final track = playlist[currentIndex];

    clips.add(
      Clip(_clipName, track.path, _clipStart, _clipEnd),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Clip saved")),
    );

    setState(() {});
  }

Future<void> playClip(Clip clip) async {

  final index = playlist.indexWhere((t) => t.path == clip.trackPath);

  if (index != -1) {
    setState(() {
      currentIndex = index;
    });

    await loadTrack();
  }

  await _player.seek(clip.start);
  _player.play();

  _clipTimer?.cancel();

  final clipLength = clip.end - clip.start;

  _clipTimer = Timer(clipLength, () {
    if (_player.playing) {
      _player.pause();
    }
  });
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

          Container(
            height: 400,
            width: 400,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          const SizedBox(height: 30),

          Row(
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

              IconButton(
                icon: const Icon(Icons.content_cut, size: 30),
                onPressed: _openClipDialog,
              ),

              const SizedBox(width: 10),

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

          Row(
            children: [
              Text(format(position)),
              Expanded(
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
              Text(format(duration)),
            ],
          ),

          const SizedBox(height: 10),

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

          const SizedBox(height: 5),

          Expanded(
            child: clips.isEmpty
                ? const Center(
                    child: Text(
                      "No clips yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: clips.length,
                    itemBuilder: (context, index) {
                      final clip = clips[index];

                      return Card(
                        color: Colors.grey[900],
                        child: ListTile(
                          visualDensity: const VisualDensity(vertical: -4),
                          title: Text(
                            clip.clipName,
                          ),
                          subtitle: Text(
                            "${format(clip.start)} → ${format(clip.end)}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => playClip(clip),
                            iconSize: 30,
                          ),
                        ),
                      );
                    },
                  ),
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
                const Icon(Icons.volume_up, size: 40),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 40,
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 40),
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
                const Icon(Icons.volume_off, size: 40),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}