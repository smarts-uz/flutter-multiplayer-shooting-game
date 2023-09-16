import 'package:flame/game.dart';
import 'package:flame_realtime_shooting/game/game.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() async{
  await Supabase.initialize(
    url: 'https://zhfyvsfmdsyrljhylxyk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpoZnl2c2ZtZHN5cmxqaHlseHlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTQ2OTM3MjgsImV4cCI6MjAxMDI2OTcyOH0.W9Hr1aLino9s65g-XgUIHoQ2jahQgg2JJdaJ9hlB1_Y',
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 40),
  );
  runApp(const MyApp());
}

// Extract Supabase client for easy access to Supabase
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'UFO Shooting Game',
      debugShowCheckedModeBanner: false,
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MyGame _game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
          GameWidget(game: _game),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _game = MyGame(
      onGameStateUpdate: (position, health) async {
        // TODO: handle game state update here
      },
      onGameOver: (playerWon) async {
        // TODO: handle when the game is over here
      },
    );

    // await for a frame so that the widget mounts
    await Future.delayed(Duration.zero);

    if (mounted) {
      _openLobbyDialog();
    }
  }

  void _openLobbyDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _LobbyDialog(
            onGameStarted: (gameId) async {
              // handle game start here
            },
          );
        });
  }
}

class _LobbyDialog extends StatefulWidget {
  const _LobbyDialog({
    required this.onGameStarted,
  });

  final void Function(String gameId) onGameStarted;

  @override
  State<_LobbyDialog> createState() => _LobbyDialogState();
}

class _LobbyDialogState extends State<_LobbyDialog> {
  List<String> _userids = [];
  bool _loading = false;

  /// Unique identifier for each players to identify each other in lobby
  final myUserId = const Uuid().v4();

  late final RealtimeChannel _lobbyChannel;

  @override
  void initState() {
    super.initState();

    _lobbyChannel = supabase.channel(
      'lobby',
      opts: const RealtimeChannelConfig(self: true),
    );
    _lobbyChannel.on(RealtimeListenTypes.presence, ChannelFilter(event: 'sync'),
            (payload, [ref]) {
          // Update the lobby count
          final presenceState = _lobbyChannel.presenceState();

          setState(() {
            _userids = presenceState.values
                .map((presences) =>
            (presences.first as Presence).payload['user_id'] as String)
                .toList();
          });
        }).on(RealtimeListenTypes.broadcast, ChannelFilter(event: 'game_start'),
            (payload, [_]) {
          // Start the game if someone has started a game with you
          final participantIds = List<String>.from(payload['participants']);
          if (participantIds.contains(myUserId)) {
            final gameId = payload['game_id'] as String;
            widget.onGameStarted(gameId);
            Navigator.of(context).pop();
          }
        }).subscribe(
          (status, [ref]) async {
        if (status == 'SUBSCRIBED') {
          await _lobbyChannel.track({'user_id': myUserId});
        }
      },
    );
  }

  @override
  void dispose() {
    supabase.removeChannel(_lobbyChannel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lobby'),
      content: _loading
          ? const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      )
          : Text('${_userids.length} users waiting'),
      actions: [
        TextButton(
          onPressed: _userids.length < 2
              ? null
              : () async {
            setState(() {
              _loading = true;
            });

            final opponentId =
            _userids.firstWhere((userId) => userId != myUserId);
            final gameId = const Uuid().v4();
            await _lobbyChannel.send(
              type: RealtimeListenTypes.broadcast,
              event: 'game_start',
              payload: {
                'participants': [
                  opponentId,
                  myUserId,
                ],
                'game_id': gameId,
              },
            );
          },
          child: const Text('start'),
        ),
      ],
    );
  }
}
