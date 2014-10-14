import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:color/color.dart';
import 'array2d.dart';

void main() {
  CanvasElement canvas = querySelector("#area");
  scheduleMicrotask(new Board(canvas, 60, new Point(48, 48), 3, 200).start);
}

Element notes = querySelector("#fps");
num fpsAverage;

/// Display the animation's FPS in a div.
void showFps(num fps) {
  if (fpsAverage == null) fpsAverage = fps;
  fpsAverage = fps * 0.05 + fpsAverage * 0.95;
  notes.text = "${fpsAverage.round()} fps";
}


class Board {
  CanvasElement canvas;
  var rng = new Random();

  Settings settings;

  num width;
  num height;

  int noAnts;
  int noColor;
  int noBlocks;

  num renderTime;
  num lastTime = 0;

  var ants = [];
  Array2d<Block> blocks;

  Board(this.canvas, this.noAnts, Point boardSize, int this.noColor, int this.noBlocks) {
    settings = new Settings();
    settings.boardSize = boardSize;

    blocks = new Array2d<Block>(boardSize.x, boardSize.y);
  }

  start() {
    // Measure the canvas element.
    Rectangle rect = canvas.parent.client;
    width = rect.width;
    height = rect.height;
    canvas.width = width;

    num size = min(width, height);
    settings.cellSize = new Point(size / settings.boardSize.x, size / settings.boardSize.y);

    for (int i = 0; i < noAnts; i++) {
      ants.add(new Ant(
          settings,
          rng.nextInt(settings.boardSize.x),
          rng.nextInt(settings.boardSize.y)
      ));
    }

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

    requestRedraw();
  }

  void draw(num _) {
    num time = new DateTime.now().millisecondsSinceEpoch;
    if (renderTime != null) showFps(1000 / (time - renderTime));
    renderTime = time;
    var context = canvas.context2D;

    drawBackground(context);
    drawBlocks(context);
    drawAnts(context);

    requestRedraw();

    num passed = time - lastTime;
    if (passed > settings.speed) {
      lastTime = time;
      step();
    }
  }

  void step() {
    ants.forEach(collision);
  }

  void collision(Ant ant) {
    ant.step();

    if (blocks[ant.x][ant.y] != null) {
      if (ant.block == null) {
        ant.block = blocks[ant.x][ant.y];
        blocks[ant.x][ant.y] = null;
      }
    } else if (ant.block != null) {
      //print("Position: " + ant.x.toString() + "x" + ant.y.toString());
      for (Block b in getNeighbourBlocks(ant.x, ant.y)) {
        //print("Neighbour: " + b.x.toString() + "x" + b.y.toString());
        if (b.color.toString() == ant.block.color.toString()) {
          //print(b.color.toString() + " vs. " + ant.block.color.toString());s
          blocks[ant.x][ant.y] = ant.block;
          ant.block = null;
          break;
        }
      }
      //print("---------");
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

  void requestRedraw() {
    window.requestAnimationFrame(draw);
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
  num speed = 10;
  Point boardSize;
  Point cellSize;
}

class Ant {
  static Random rng = new Random();
  Settings settings;

  Block block = null;
  num x;
  num y;

  Ant(this.settings, this.x, this.y);

  void step() {
    switch (rng.nextInt(4)) {
      case 0:
        x += 1;
        break;
      case 1:
        x -= 1;
        break;
      case 2:
        y += 1;
        break;
      default:
        y -= 1;
        break;
    }

    x = min(x, settings.boardSize.x-1);
    x = max(0, x);
    y = min(y, settings.boardSize.y-1);
    y = max(0, y);

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