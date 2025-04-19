import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SnakeGame());

/* ────────────────  App Shell  ──────────────── */

class SnakeGame extends StatelessWidget {
  const SnakeGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameSettingsScreen(),
    );
  }
}

/* ────────────────  Settings Screen  ──────────────── */

class GameSettingsScreen extends StatefulWidget {
  const GameSettingsScreen({super.key});

  @override
  State<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends State<GameSettingsScreen> {
  String lifeLostBehavior = 'resume';   // 'resume' | 'wait'
  String wallRule         = 'loseLife'; // 'loseLife' | 'goThrough'
  int   startLives        = 3;          // 3 | 5

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* life‑lost behaviour */
            const Text('When life is lost:'),
            ListTile(
              title: const Text('Resume automatically'),
              leading: Radio<String>(
                value: 'resume',
                groupValue: lifeLostBehavior,
                onChanged: (v) => setState(() => lifeLostBehavior = v!),
              ),
            ),
            ListTile(
              title: const Text('Pause and wait for Space'),
              leading: Radio<String>(
                value: 'wait',
                groupValue: lifeLostBehavior,
                onChanged: (v) => setState(() => lifeLostBehavior = v!),
              ),
            ),
            const SizedBox(height: 12),
            /* wall rule */
            const Text('Wall rule:'),
            ListTile(
              title: const Text('Lose life if snake hits wall'),
              leading: Radio<String>(
                value: 'loseLife',
                groupValue: wallRule,
                onChanged: (v) => setState(() => wallRule = v!),
              ),
            ),
            ListTile(
              title: const Text('Snake goes through walls (wrap)'),
              leading: Radio<String>(
                value: 'goThrough',
                groupValue: wallRule,
                onChanged: (v) => setState(() => wallRule = v!),
              ),
            ),
            const SizedBox(height: 12),
            /* lives selection */
            const Text('Starting lives:'),
            ListTile(
              title: const Text('3 lives'),
              leading: Radio<int>(
                value: 3,
                groupValue: startLives,
                onChanged: (v) => setState(() => startLives = v!),
              ),
            ),
            ListTile(
              title: const Text('5 lives'),
              leading: Radio<int>(
                value: 5,
                groupValue: startLives,
                onChanged: (v) => setState(() => startLives = v!),
              ),
            ),
            const Spacer(),
            /* launch */
            Center(
              child: ElevatedButton(
                child: const Text('Start Game'),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      lifeLostBehavior: lifeLostBehavior,
                      wallRule:         wallRule,
                      initialLives:     startLives,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ────────────────  Game Screen  ──────────────── */

class GameScreen extends StatefulWidget {
  final String lifeLostBehavior;
  final String wallRule;
  final int    initialLives;
  const GameScreen({
    super.key,
    this.lifeLostBehavior = 'resume',
    this.wallRule         = 'loseLife',
    this.initialLives     = 3,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /* ── constants & state ── */
  static const int gridSize = 20;
  static const int initialSnakeLength = 3;

  late List<Offset> snake;         // current snake segments
  late int          snakeLength;   // target length (grows with score)
  late Offset apple;
  final List<Offset> obstacles = [];

  String direction = 'right';
  int score = 0;
  late int lives;

  final FocusNode _focusNode = FocusNode();
  Timer? timer;

  /* ── direction helper ── */

  static const _opposite = {
    'up':    'down',
    'down':  'up',
    'left':  'right',
    'right': 'left',
  };

  void changeDirection(String newDir) {
    if (_opposite[direction] == newDir) return; // ignore reverse
    setState(() => direction = newDir);
  }

  /* ── lifecycle ── */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
    lives = widget.initialLives;
    _startRound(
      length: initialSnakeLength,
      resetScore: true,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /* ── round helpers ── */

  void _startRound({required int length, required bool resetScore}) {
    snakeLength = length;
    snake = List.generate(
        snakeLength, (i) => Offset(i.toDouble(), 0)); // fresh horizontal snake
    direction = 'right';
    if (resetScore) score = 0;
    obstacles.clear();
    _spawnApple();
    _restartTimer();
    setState(() {});
  }

  void _restartTimer() {
    timer?.cancel();
    timer =
        Timer.periodic(const Duration(milliseconds: 200), (_) => _moveSnake());
  }

  /* ── spawning ── */

  final _rand = Random();

  void _spawnApple() {
    Offset pos;
    do {
      pos = Offset(
        _rand.nextInt(gridSize).toDouble(),
        _rand.nextInt(gridSize).toDouble(),
      );
    } while (snake.contains(pos) || obstacles.contains(pos));
    apple = pos;
  }

  void _spawnObstacle() {
    Offset pos;
    do {
      pos = Offset(
        _rand.nextInt(gridSize).toDouble(),
        _rand.nextInt(gridSize).toDouble(),
      );
    } while (snake.contains(pos) || apple == pos || obstacles.contains(pos));
    obstacles.add(pos);
  }

  /* ── game loop ── */

  Future<void> _moveSnake() async {
    Offset head = snake.last;
    switch (direction) {
      case 'up':
        head = Offset(head.dx, head.dy - 1);
        break;
      case 'down':
        head = Offset(head.dx, head.dy + 1);
        break;
      case 'left':
        head = Offset(head.dx - 1, head.dy);
        break;
      case 'right':
        head = Offset(head.dx + 1, head.dy);
        break;
    }

    bool hitWall = head.dx < 0 ||
        head.dy < 0 ||
        head.dx >= gridSize ||
        head.dy >= gridSize;
    bool hitSelf = snake.contains(head);
    bool hitObstacle = obstacles.contains(head);

    if (widget.wallRule == 'goThrough' && hitWall) {
      head = Offset(
        (head.dx + gridSize) % gridSize,
        (head.dy + gridSize) % gridSize,
      );
      hitWall = false;
    }

    if (hitWall || hitSelf || hitObstacle) {
      await _handleLifeLost();
      return;
    }

    setState(() {
      snake.add(head);

      if (head == apple) {
        score += 10;
        snakeLength += 1;          // grow
        _spawnApple();
        if (score % 20 == 0) _spawnObstacle();
      }

      while (snake.length > snakeLength) {
        snake.removeAt(0);
      }
    });
  }

  /* ── life‑lost / game‑over ── */

  Future<void> _handleLifeLost() async {
    lives -= 1;
    timer?.cancel();
    await _showLifeLostSplash();

    if (lives == 0) {
      _showGameOver();
      return;
    }

    if (widget.lifeLostBehavior == 'wait') return;

    // restart round with SAME earned length, keep score
    _startRound(length: snakeLength, resetScore: false);
  }

  Future<void> _showLifeLostSplash() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        content: const Text(
          '⚠️  Life Lost!',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('Your score: $score'),
        actions: [
          TextButton(
            child: const Text('Restart'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                lives = widget.initialLives;
                _startRound(
                    length: initialSnakeLength, resetScore: true);
              });
            },
          ),
          TextButton(
            child: const Text('Exit'),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const GameSettingsScreen()),
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }

  /* ── input ── */

  void _handleKey(RawKeyEvent e) {
    if (e is! RawKeyDownEvent) return;

    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      changeDirection('up');
    } else if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      changeDirection('down');
    } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      changeDirection('left');
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      changeDirection('right');
    } else if (e.logicalKey == LogicalKeyboardKey.space &&
        widget.lifeLostBehavior == 'wait' &&
        (timer == null || !timer!.isActive)) {
      _restartTimer();
    }
  }

  Widget _dirButton(IconData icon, String dir) => IconButton(
        iconSize: 40,
        icon: Icon(icon),
        onPressed: () => changeDirection(dir),
      );

  /* ── build ── */

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: _handleKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('Snake')),
        body: Column(
          children: [
            /* score bar */
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Score: $score',
                      style: const TextStyle(fontSize: 18)),
                  Text('Lives:  $lives',
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            /* game grid */
            Expanded(
              child: Container(
                color: Colors.black,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (_, index) {
                    final x = index % gridSize;
                    final y = index ~/ gridSize;
                    final pos = Offset(x.toDouble(), y.toDouble());

                    Color color;
                    if (snake.contains(pos)) {
                      color = Colors.yellow;
                    } else if (pos == apple) {
                      color = Colors.green;
                    } else if (obstacles.contains(pos)) {
                      color = Colors.red;
                    } else {
                      color = Colors.grey.shade900;
                    }

                    return Container(
                      margin: const EdgeInsets.all(1),
                      color: color,
                    );
                  },
                ),
              ),
            ),
            /* on‑screen controls */
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _dirButton(Icons.arrow_upward, 'up'),
                  _dirButton(Icons.arrow_downward, 'down'),
                  _dirButton(Icons.arrow_back, 'left'),
                  _dirButton(Icons.arrow_forward, 'right'),
                ],
              ),
            ),
            /* exit btn */
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton(
                child: const Text('Exit & Restart'),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const GameSettingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
