import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Wall Detector'),
        ),
        body: const Body(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Body extends ConsumerStatefulWidget {
  const Body({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _BodyState();
}

class _BodyState extends ConsumerState<Body> {
  img.Image? decodedImg;
  int filter = 0;
  int w = 500, h = 500;
  String name = 'No file yet';
  List<Line> lines = [];
  bool running = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton(
            child: Text('Picker Map: $name'),
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? pickimg =
                  await picker.pickImage(source: ImageSource.gallery);
              if (pickimg != null) {
                final image = await pickimg.readAsBytes();
                setState(() {
                  decodedImg = img.decodeImage(image);
                  name = pickimg.name;
                  h = decodedImg!.height;
                  w = decodedImg!.width;
                });
              }
            }),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Filter'),
            Expanded(
              child: Slider(
                  min: 0,
                  max: 255 * 3,
                  label: filter.toString(),
                  value: filter.toDouble(),
                  divisions: 20,
                  onChanged: (v) {
                    setState(() {
                      filter = v.round();
                    });
                  }),
            ),
          ],
        ),
        OutlinedButton(
            onPressed: running
                ? null
                : () async {
                    if (decodedImg != null) {
                      setState(() {
                        running = true;
                      });
                      List<Line> result = await compute(getLineFromImg,
                          ImgToLineInput(decodedImg!, filter: filter));
                      setState(() {
                        lines = result;
                        running = false;
                      });
                    }
                  },
            child: const Text('Run')),
        SizedBox(
          height: 200,
          child: ListView.builder(
            itemBuilder: (context, idx) => ListTile(
              subtitle: Text(
                  '${lines[idx].x1},${lines[idx].y1}\nto: ${lines[idx].x2},${lines[idx].y2}'),
            ),
            itemCount: lines.length,
          ),
        ),
        Expanded(
          child: FittedBox(
            child: ColoredBox(
              color: Colors.blue,
              child: CustomPaint(
                size: Size(w.toDouble(), h.toDouble()),
                painter: ImgPainter(decodedImg: decodedImg, filter: filter),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

List<Line> getLineFromImg(ImgToLineInput inp) {
  int h = inp.decodedImg.height, w = inp.decodedImg.width;
  print('$w x $h');
  List<List<bool>> m = List.generate(h, (i) => List.generate(w, (j) => false));
  for (var pixel in inp.decodedImg) {
    m[pixel.y][pixel.x] = pixel.r + pixel.g + pixel.b <= inp.filter;
  }
  List<Line> lines = [];
  List<PointState> stack = [];
  for (int i = 0; i < h; i++) {
    for (int j = 0; j < w; j++) {
      if (m[i][j]) {
        stack.addAll(checkPoint(m, j, i));
        m[i][j] = false;
      }
      while (stack.isNotEmpty) {
        print('stack: ${stack.length}');
        print('line: ${lines.length}');
        stack.removeLast();
        PointState item = stack.last;
        int nx = item.x, ny = item.y;
        switch (item.dir) {
          case Dir.u:
            ny--;
            while (ny >= 0) {
              if (m[ny][nx]) {
                stack.addAll(checkPoint(m, nx, ny));
                ny--;
                m[ny][nx] = false;
              } else {
                ny++;
                if (ny != item.y) {
                  lines.add(Line(item.x, item.y, nx, ny));
                }
                break;
              }
            }
            break;
          case Dir.d:
            ny++;
            while (ny < h) {
              if (m[ny][nx]) {
                stack.addAll(checkPoint(m, nx, ny));
                ny++;
                m[ny][nx] = false;
              } else {
                ny--;
                if (ny != item.y) {
                  lines.add(Line(item.x, item.y, nx, ny));
                }
                break;
              }
            }
            break;
          case Dir.l:
            nx--;
            while (nx >= 0) {
              if (m[ny][nx]) {
                stack.addAll(checkPoint(m, nx, ny));
                nx--;
                m[ny][nx] = false;
              } else {
                nx++;
                if (nx != item.x) {
                  lines.add(Line(item.x, item.y, nx, ny));
                }
                break;
              }
            }
            break;
          case Dir.r:
            ny++;
            while (nx < w) {
              if (m[ny][nx]) {
                stack.addAll(checkPoint(m, nx, ny));
                nx++;
                m[ny][nx] = false;
              } else {
                nx--;
                if (nx != item.x) {
                  lines.add(Line(item.x, item.y, nx, ny));
                }
                break;
              }
            }
            break;
        }
      }
    }
  }
  return lines;
}

List<PointState> checkPoint(List<List<bool>> m, int x, int y) {
  int h = m.length, w = m.first.length;
  List<PointState> result = [];
  if (y > 0 && m[y - 1][x]) {
    result.add(PointState(x, y, Dir.u));
  }
  if (y < h - 1 && m[y + 1][x]) {
    result.add(PointState(x, y, Dir.d));
  }
  if (x > 0 && m[y][x - 1]) {
    result.add(PointState(x, y, Dir.l));
  }
  if (x < w - 1 && m[y][x + 1]) {
    result.add(PointState(x, y, Dir.r));
  }
  return result;
}

class Line {
  int x1, x2, y1, y2;
  Line(this.x1, this.y1, this.x2, this.y2);
}

class ImgToLineInput {
  img.Image decodedImg;
  int filter;
  ImgToLineInput(this.decodedImg, {this.filter = 0});
}

enum Dir { u, d, l, r }

class PointState {
  int x, y;
  Dir dir;
  PointState(this.x, this.y, this.dir);
}

class ImgPainter extends CustomPainter {
  img.Image? decodedImg;
  int filter;

  ImgPainter({this.decodedImg, required this.filter});

  @override
  void paint(Canvas canvas, Size size) {
    final b = Paint()..color = Colors.black;
    final r = Paint()..color = Colors.white;
    // canvas.drawPoints(
    //     PointMode.points,
    //     colorList.map((e) => Offset(e.x.toDouble(), e.y.toDouble())).toList(),
    //     b);
    if (decodedImg != null) {
      for (var pixel in decodedImg!) {
        canvas.drawRect(
            Rect.fromLTWH(pixel.x.toDouble(), pixel.y.toDouble(), 1, 1),
            pixel.r + pixel.g + pixel.b <= filter ? b : r);
        // if (pixel.r + pixel.g + pixel.b == 0)
        //   print('${pixel.x} ${pixel.y}\t\t ${pixel.r} ${pixel.g} ${pixel.b}');
      }
    }
  }

  @override
  bool shouldRepaint(ImgPainter oldDelegate) =>
      filter != oldDelegate.filter || decodedImg != oldDelegate.decodedImg;
}
