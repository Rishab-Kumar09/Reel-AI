import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class LoadingGame extends StatefulWidget {
  final VoidCallback onTranscriptReady;

  const LoadingGame({Key? key, required this.onTranscriptReady})
      : super(key: key);

  @override
  State<LoadingGame> createState() => _LoadingGameState();
}

class _LoadingGameState extends State<LoadingGame>
    with SingleTickerProviderStateMixin {
  static const int rows = 8;
  static const int columns = 6;
  static const double cellSize = 50.0;

  late List<List<Candy>> grid;
  Offset? selectedCandy;
  int score = 0;
  bool isSwapping = false;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    initializeGrid();
  }

  void initializeGrid() {
    grid = List.generate(
        rows, (i) => List.generate(columns, (j) => _createRandomCandy()));
    // Check for initial matches and refill
    while (_findMatches().isNotEmpty) {
      _removeMatches(_findMatches());
      _fillEmptyCells();
    }
  }

  Candy _createRandomCandy() {
    final candyTypes = [
      CandyType.red,
      CandyType.blue,
      CandyType.green,
      CandyType.yellow,
      CandyType.purple,
    ];
    return Candy(type: candyTypes[random.nextInt(candyTypes.length)]);
  }

  void _handleTap(int row, int col) {
    if (isSwapping) return;

    setState(() {
      if (selectedCandy == null) {
        selectedCandy = Offset(row.toDouble(), col.toDouble());
      } else {
        final previousRow = selectedCandy!.dx.toInt();
        final previousCol = selectedCandy!.dy.toInt();

        if (_isAdjacent(previousRow, previousCol, row, col)) {
          _swapCandies(previousRow, previousCol, row, col);
        }
        selectedCandy = null;
      }
    });
  }

  bool _isAdjacent(int row1, int col1, int row2, int col2) {
    return (row1 == row2 && (col1 - col2).abs() == 1) ||
        (col1 == col2 && (row1 - row2).abs() == 1);
  }

  Future<void> _swapCandies(int row1, int col1, int row2, int col2) async {
    isSwapping = true;
    setState(() {
      final temp = grid[row1][col1];
      grid[row1][col1] = grid[row2][col2];
      grid[row2][col2] = temp;
    });

    // Check for matches after swap
    await Future.delayed(const Duration(milliseconds: 300));
    final matches = _findMatches();

    if (matches.isEmpty) {
      // Swap back if no matches
      setState(() {
        final temp = grid[row1][col1];
        grid[row1][col1] = grid[row2][col2];
        grid[row2][col2] = temp;
      });
    } else {
      // Remove matches and fill empty cells
      _processMatches(matches);
    }

    isSwapping = false;
  }

  List<List<Offset>> _findMatches() {
    List<List<Offset>> matches = [];

    // Check horizontal matches
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns - 2; j++) {
        if (grid[i][j].type == grid[i][j + 1].type &&
            grid[i][j].type == grid[i][j + 2].type) {
          matches.add([
            Offset(i.toDouble(), j.toDouble()),
            Offset(i.toDouble(), (j + 1).toDouble()),
            Offset(i.toDouble(), (j + 2).toDouble()),
          ]);
        }
      }
    }

    // Check vertical matches
    for (int i = 0; i < rows - 2; i++) {
      for (int j = 0; j < columns; j++) {
        if (grid[i][j].type == grid[i + 1][j].type &&
            grid[i][j].type == grid[i + 2][j].type) {
          matches.add([
            Offset(i.toDouble(), j.toDouble()),
            Offset((i + 1).toDouble(), j.toDouble()),
            Offset((i + 2).toDouble(), j.toDouble()),
          ]);
        }
      }
    }

    return matches;
  }

  Future<void> _processMatches(List<List<Offset>> matches) async {
    // Remove matches
    _removeMatches(matches);

    // Add score
    setState(() {
      score += matches.length * 30;
    });

    // Fill empty cells
    await Future.delayed(const Duration(milliseconds: 300));
    _fillEmptyCells();

    // Check for new matches
    await Future.delayed(const Duration(milliseconds: 300));
    final newMatches = _findMatches();
    if (newMatches.isNotEmpty) {
      await _processMatches(newMatches);
    }
  }

  void _removeMatches(List<List<Offset>> matches) {
    setState(() {
      for (final match in matches) {
        for (final offset in match) {
          grid[offset.dx.toInt()][offset.dy.toInt()] =
              Candy(type: CandyType.empty);
        }
      }
    });
  }

  void _fillEmptyCells() {
    setState(() {
      // Move candies down
      for (int col = 0; col < columns; col++) {
        for (int row = rows - 1; row >= 0; row--) {
          if (grid[row][col].type == CandyType.empty) {
            // Find the first non-empty cell above
            int currentRow = row;
            while (currentRow > 0 &&
                grid[currentRow][col].type == CandyType.empty) {
              currentRow--;
            }
            if (grid[currentRow][col].type != CandyType.empty) {
              grid[row][col] = grid[currentRow][col];
              grid[currentRow][col] = Candy(type: CandyType.empty);
            }
          }
        }
      }

      // Fill empty cells with new candies
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < columns; j++) {
          if (grid[i][j].type == CandyType.empty) {
            grid[i][j] = _createRandomCandy();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.purple[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Score: $score',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.purple[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    rows,
                    (i) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                              columns,
                              (j) => GestureDetector(
                                    onTap: () => _handleTap(i, j),
                                    child: Container(
                                      width: cellSize,
                                      height: cellSize,
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: selectedCandy?.dx == i &&
                                                selectedCandy?.dy == j
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: _buildCandy(grid[i][j]),
                                    ),
                                  )),
                        )),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Match 3 or more candies!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandy(Candy candy) {
    if (candy.type == CandyType.empty) return const SizedBox();

    final IconData icon;
    final Color color;

    switch (candy.type) {
      case CandyType.red:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case CandyType.blue:
        icon = Icons.star;
        color = Colors.blue;
        break;
      case CandyType.green:
        icon = Icons.brightness_1;
        color = Colors.green;
        break;
      case CandyType.yellow:
        icon = Icons.emoji_emotions;
        color = Colors.orange;
        break;
      case CandyType.purple:
        icon = Icons.diamond;
        color = Colors.purple;
        break;
      default:
        icon = Icons.circle;
        color = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: color,
        size: 30,
      ),
    );
  }
}

enum CandyType {
  empty,
  red,
  blue,
  green,
  yellow,
  purple,
}

class Candy {
  final CandyType type;

  Candy({required this.type});
}
