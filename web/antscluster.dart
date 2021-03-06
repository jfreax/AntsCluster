import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:polymer/polymer.dart';
import 'package:color/color.dart';
import 'package:game_loop/game_loop_html.dart';
import 'array2d.dart';

void main() {
  CanvasElement canvas = querySelector("#area");

  Board board = new Board(canvas, 60, new Point(248, 248), 5, 700);

  initPolymer().run(() {
    Polymer.onReady.then((_) {
      var speedSlider = querySelector('#speed');
      speedSlider.on['core-change'].listen((_) {
        board.settings.speed = speedSlider.value;
      });

      var antsSlider = querySelector('#ants');
      antsSlider.on['core-change'].listen((_) {
        board.noAnts = antsSlider.value;
      });

      var colorSlider = querySelector('#colors');
      colorSlider.on['core-change'].listen((_) {
        board.noColor = colorSlider.value;
        board.restart();
      });

      var blockSlider = querySelector('#blocks');
      blockSlider.on['core-change'].listen((_) {
        board.noBlocks = blockSlider.value;
        board.restart();
      });

      board.settings.speed = speedSlider.value;
      board.noAnts = antsSlider.value;
      board.noColor = colorSlider.value;
      board.noBlocks = blockSlider.value;
      scheduleMicrotask(board.start);
    });
  });
}

Element notes = querySelector("#fps");
num fpsAverage;

/// Display the animation's FPS in a div.
void showFps(num fps) {
  if (fpsAverage == null || fpsAverage.isInfinite || fpsAverage.isNaN)
    fpsAverage = fps;

  fpsAverage = fps * 0.05 + fpsAverage * 0.95;
  notes.text = "${fpsAverage.round()} fps";
}


class Board {
  CanvasElement canvas;
  var rng = new Random();
  GameLoopHtml gameLoop;

  Settings settings;

  num width;
  num height;

  //int noAnts;

  int get noAnts => ants.length;

  void set noAnts(int newNoAnts) {
    if (newNoAnts < ants.length) {
      ants.removeRange(newNoAnts, ants.length-1);
    } else {
      int noNew = newNoAnts - ants.length;
      for (int i = 0; i < newNoAnts; i++) {
        ants.add(new Ant(
            settings,
            rng.nextInt(settings.boardSize.x),
            rng.nextInt(settings.boardSize.y)
        ));
      }
    }
  }

  int noColor;
  int noBlocks;

  num renderTime;
  num lastTime = 0;

  var ants = [];
  Array2d<Block> blocks;

  Board(this.canvas, int ants, Point boardSize, int this.noColor, int this.noBlocks) {
    settings = new Settings();
    settings.boardSize = boardSize;
    blocks = new Array2d<Block>(boardSize.x, boardSize.y);

    this.noAnts = ants;

    gameLoop = new GameLoopHtml(canvas);
  }

  void start() {
    // Measure the canvas element.
    Rectangle rect = querySelector("body").client;
    var title = querySelector("#title");

    width = rect.width;
    height = (rect.height - title.borderEdge.height - title.marginEdge.height).round();
    print(querySelector("#title").borderEdge.height);

    num size = min(height, width);

    canvas.width = size;
    canvas.height = size;

    settings.cellSize = new Point(size / settings.boardSize.x, size / settings.boardSize.y);

    for (int c = 0; c < noColor; c++) {
      Color color = new Color.rgb(rng.nextInt(256), rng.nextInt(256), rng.nextInt(256));

      for (int b = 0; b < (noBlocks / noColor); b++) {
        num x = rng.nextInt(settings.boardSize.x);
        num y = rng.nextInt(settings.boardSize.y);

        if (blocks[x][y] == null) {
          blocks[x][y] = new Block(settings, color, x, y);
        }
      }
    }

    gameLoop.onUpdate = ((gameLoop) { step(gameLoop); });
    gameLoop.onRender = ((gameLoop) { draw(); });

    gameLoop.start();
  }

  void restart() {
    gameLoop.stop();

    ants.forEach((a) => a.block = null);
    blocks = new Array2d<Block>(settings.boardSize.x, settings.boardSize.y);
    fpsAverage = null;

    start();
  }

  void draw() {
    num time = new DateTime.now().millisecondsSinceEpoch;
    if (renderTime != null) showFps(1000 / (time - renderTime));
    renderTime = time;
    var context = canvas.context2D;

    drawBackground(context);
    drawBlocks(context);
    drawAnts(context);
  }

  void step(GameLoop gameLoop) {
    num time = new DateTime.now().millisecondsSinceEpoch;
    num stepW = settings.speed / 1000 / gameLoop.dt;

    if (stepW < 1.0) {
      if (time - lastTime >= 50 / stepW) {
        lastTime = time;
        ants.forEach(collision);
      }
    } else {
      for (int i = 0; i < stepW; i++) {
        ants.forEach(collision);
      }
    }
  }

  void collision(Ant ant) {
    ant.step();

    if (blocks[ant.x][ant.y] != null) { // aufheben
      if (ant.block == null) {
        ant.block = blocks[ant.x][ant.y];
        ant.taken = 3;
        blocks[ant.x][ant.y] = null;
      }
    } else if (ant.block != null && ant.taken <= 0) { // ablegen
      int noOfFittingNeighbours = 0;
      for (Block b in getNeighbourBlocks(ant.x, ant.y)) {
        if (b.color.toString() == ant.block.color.toString()) {
          noOfFittingNeighbours++;

          if (noOfFittingNeighbours >= 2) {
            blocks[ant.x][ant.y] = ant.block;
            ant.block = null;
            break;
          }
        }
      }
    }
  }

  void drawBackground(CanvasRenderingContext2D context) {
    context.clearRect(0, 0, width, height);
  }

  void drawAnts(CanvasRenderingContext2D context) {
    ants.forEach((a) => a.draw(canvas.context2D));
  }

  void drawBlocks(CanvasRenderingContext2D context) {
    for (int i = 0; i < settings.boardSize.x; i++) {
      for (int j = 0; j < settings.boardSize.y; j++) {
        if (blocks[i][j] != null) {
          blocks[i][j].draw(context);
        }
      }
    }
  }

  List<Block> getNeighbourBlocks(int x, int y) {
    List<Block> neighbours = new List<Block>();
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        if (i == 0 && j == 0) {
          continue;
        }

        int x2 = x + i;
        int y2 = y + j;
        if (x2 == -1) {
          x2 = settings.boardSize.x-1;
        } else if (x2 >= settings.boardSize.x) {
          x2 = 0;
        }
        if (y2 == -1) {
          y2 = settings.boardSize.y-1;
        } else if (y2 >= settings.boardSize.y) {
          y2 = 0;
        }

        if (blocks[x2][y2] != null) {
          neighbours.add(blocks[x2][y2]);
        }
      }
    }

    return neighbours;
  }
}

class Settings {
  num speed = 100;
  Point boardSize;
  Point cellSize;
}

class Ant {
  static Random rng = new Random();
  Settings settings;

  Block block = null;
  num x;
  num y;
  int direction = rng.nextInt(4);

  num taken = 0;

  Ant(this.settings, this.x, this.y);

  void step() {
    taken--;

    if (rng.nextInt(5) <= 1) {
      direction += (rng.nextInt(3) - 1);

      if (direction < 0) {
        direction = 3;
      } else if (direction > 3) {
        direction = 0;
      }
    }

    switch (direction) {
      case 0:
        y -= 1;
        break;
      case 1:
        x += 1;
        break;
      case 2:
        y += 1;
        break;
      default:
        x -= 1;
        break;
    }

    if (x < 0) {
      x = settings.boardSize.x - 1;
    } else if (x >= settings.boardSize.x) {
      x = 0;
    }
    if (y < 0) {
      y = settings.boardSize.y - 1;
    } else if (y >= settings.boardSize.y) {
      y = 0;
    }

    if (block != null) {
      block.x = x;
      block.y = y;
    }
  }

  void draw(CanvasRenderingContext2D context) {
    if (block != null) {
      block.draw(context);
    }

    context..beginPath()
           ..fillStyle = "#ff00ee"
           ..arc((x + 0.5) * settings.cellSize.x, (y + 0.5) * settings.cellSize.y, settings.cellSize.x * 0.3, 0, 360)
           ..fill()..stroke();
  }
}

class Block {
  Settings settings;

  Color color;
  num x;
  num y;


  Block(this.settings, this.color, this.x, this.y);

  void draw(CanvasRenderingContext2D context) {
    context..beginPath()
      ..fillStyle = "#" + color.toHexString()
      ..fillRect(x * settings.cellSize.x, y * settings.cellSize.y, settings.cellSize.x, settings.cellSize.y)
      ..fill()..stroke();

  }
}