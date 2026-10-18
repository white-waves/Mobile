import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../engine/palette.dart';
import '../engine/text.dart';
import '../models/player_stats.dart';
import '../services/api_client.dart';
import 'scene.dart';

// Таблиця лідерів з прокруткою пальцем.
class LeaderboardScene extends Scene with DragCallbacks {
  List<LeaderboardEntry>? _rows;
  String? _error;
  double _scroll = 0;

  @override
  void build() {
    backButton();
    _load();
  }

  Future<void> _load() async {
    try {
      _rows = await game.auth.api.leaderboard(limit: 100);
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  double get _listTop => 36;
  double get _rowH => 14;

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final rows = _rows?.length ?? 0;
    final maxScroll = (rows * _rowH - (h - _listTop - 8)).clamp(0, double.infinity).toDouble();
    _scroll = (_scroll - event.localDelta.y).clamp(0, maxScroll).toDouble();
  }

  @override
  void render(Canvas canvas) {
    drawHeader(canvas, 'ЛІДЕРИ');
    PixelText.draw(canvas, '#', 8, 24);
    PixelText.draw(canvas, 'КАПІТАН', 32, 24);
    PixelText.draw(canvas, 'ОЧКИ', w - 8, 24, align: TAlign.right);
    canvas.px(8, 33, w - 16, 1);
    final rows = _rows;
    if (_error != null) {
      PixelText.drawWrapped(canvas, _error!, 8, 44, w - 16);
      return;
    }
    if (rows == null) {
      if ((time * 2).floor().isEven) PixelText.draw(canvas, 'ЗАВАНТАЖЕННЯ...', 8, 44);
      return;
    }
    if (rows.isEmpty) {
      PixelText.drawWrapped(canvas, 'ПОКИ ЩО ПОРОЖНЬО. СТАНЬ ПЕРШИМ!', 8, 44, w - 16);
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, _listTop, w, h - _listTop));
    final me = game.auth.nickname;
    final maxNick = ((w - 32 - 8 - 48) / 8).floor();
    for (var i = 0; i < rows.length; i++) {
      final y = _listTop + i * _rowH - _scroll;
      if (y < _listTop - _rowH || y > h) continue;
      final r = rows[i];
      final mine = r.nickname == me;
      if (mine) canvas.px(4, y, w - 8, _rowH);
      var nick = r.nickname;
      if (nick.length > maxNick) nick = '${nick.substring(0, maxNick - 1)}.';
      PixelText.draw(canvas, '${r.rank}', 8, y + 3, paper: mine);
      PixelText.draw(canvas, nick, 32, y + 3, paper: mine);
      PixelText.draw(canvas, '${r.points}', w - 8, y + 3, paper: mine, align: TAlign.right);
      // медалі першій трійці
      if (r.rank <= 3) canvas.px(26, y + 5, 2, 4, mine);
    }
    canvas.restore();
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;
}
