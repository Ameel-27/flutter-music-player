import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  runApp(MyApp());
}

class Song {
  final String title;
  final String url;
  final String thumbnail;

  Song({required this.title, required this.url, required this.thumbnail});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Music Player",
      theme: ThemeData.dark(),
      home: PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final TextEditingController controller = TextEditingController();
  final AudioPlayer player = AudioPlayer();

  List<Song> queue = [];

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  Song? currentSong;
  Song? preloadedSong;

  bool isSearching = false;
  bool isBuffering = false;

  @override
  void initState() {
    super.initState();

    player.positionStream.listen((p) {
      setState(() => position = p);
    });

    player.durationStream.listen((d) {
      if (d != null) setState(() => duration = d);
    });

    player.playerStateStream.listen((state) {
      setState(() {
        isBuffering =
            state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading;
      });

      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
    });
  }

  Future<void> searchAndAdd(String query) async {
    if (queue.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Queue is full! Maximum 10 songs allowed."),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => isSearching = true);

    try {
      final response = await http.get(
        Uri.parse("http://bardi.fsc-clan.eu/search?query=$query"),
      );

      final data = json.decode(response.body);

      if (data["error"] != null) {
        print("Error: ${data["error"]}");
        return;
      }

      final song = Song(
        title: data["title"],
        url: data["audio_url"],
        thumbnail: data["thumbnail"],
      );

      setState(() {
        queue.add(song);
      });

      if (currentSong == null) {
        playNext().then((_) => preloadNext());
      }
    } catch (e) {
      print("Search error: $e");
    } finally {
      setState(() => isSearching = false);
    }
  }

  Future<void> playNext() async {
    if (queue.isEmpty && preloadedSong == null) {
      stop();
      return;
    }

    Song next;
    if (preloadedSong != null) {
      next = preloadedSong!;
      preloadedSong = null;
    } else {
      next = queue.removeAt(0);
    }

    setState(() {
      currentSong = next;
    });

    try {
      await player.setUrl(next.url);
      player.play();

      preloadNext();
    } catch (e) {
      print("AUDIO LOAD ERROR: $e");
    }
  }

  Future<void> preloadNext() async {
    if (queue.isEmpty) return;

    final next = queue.first;

    try {
      await player.setUrl(next.url);

      preloadedSong = next;
    } catch (e) {
      print("Preload error: $e");
      preloadedSong = null;
    }
  }

  void togglePlayPause() {
    if (currentSong == null) return;

    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void stop() async {
    await player.stop();
    await player.seek(Duration.zero);

    setState(() {
      currentSong = null;
      position = Duration.zero;
      duration = Duration.zero;
    });
  }

  String format(Duration d) {
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("🎵 Music Player")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (isSearching) ...[
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 10),
                  Text("Searching..."),
                ],
              ),
              SizedBox(height: 10),
            ],

            TextField(
              enabled: !isSearching,
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                final query = value.trim();
                if (query.isEmpty || isSearching) return;
                searchAndAdd(value);
                controller.clear();
              },
              decoration: InputDecoration(
                hintText: "Search song...",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: isSearching
                      ? null
                      : () {
                          final query = controller.text.trim();
                          if (query.isEmpty || isSearching) return;
                          searchAndAdd(controller.text);
                          controller.clear();
                        },
                ),
              ),
            ),

            SizedBox(height: 20),

            if (currentSong != null) ...[
              if (isBuffering)...{
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text("Buffering..."),
                  ],
                ),
                SizedBox(height: 20),
              },
              CachedNetworkImage(
                imageUrl: currentSong!.thumbnail,
                height: 150,
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),

              Text(
                currentSong!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              Slider(
                value: position.inSeconds.toDouble(),
                max: duration.inSeconds.toDouble() == 0
                    ? 1
                    : duration.inSeconds.toDouble(),
                onChanged: (value) {
                  player.seek(Duration(seconds: value.toInt()));
                },
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(format(position)), Text(format(duration))],
              ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: currentSong == null && queue.isEmpty
                      ? null
                      : () async {
                          await playNext();
                          await preloadNext();
                        },
                ),
                IconButton(
                  icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: currentSong == null ? null : togglePlayPause,
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: currentSong == null ? null : stop,
                ),
              ],
            ),

            Divider(),

            Expanded(
              child: ListView.builder(
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final song = queue[index];
                  return ListTile(
                    leading: CachedNetworkImage(
                      imageUrl: song.thumbnail,
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        setState(() => queue.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
