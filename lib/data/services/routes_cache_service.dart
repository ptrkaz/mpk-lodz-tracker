import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/line.dart';
import '../../domain/models/vehicle.dart';

typedef DirectoryProvider = Future<Directory> Function();

class RoutesCacheService {
  RoutesCacheService({DirectoryProvider? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final DirectoryProvider _directoryProvider;

  static const _fileName = 'routes.json';

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
  }

  Future<RoutesIndex?> read({required Duration maxAge}) async {
    final file = await _file();
    if (!file.existsSync()) return null;
    final modified = await file.lastModified();
    if (DateTime.now().difference(modified) > maxAge) return null;

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, Line>{};
    decoded.forEach((routeId, value) {
      final m = value as Map<String, dynamic>;
      out[routeId] = Line(
        routeId: m['routeId'] as String,
        number: m['number'] as String,
        type: VehicleType.values.firstWhere(
          (t) => t.name == (m['type'] as String),
          orElse: () => VehicleType.unknown,
        ),
      );
    });
    return out;
  }

  Future<void> write(RoutesIndex index) async {
    final file = await _file();
    final encoded = <String, dynamic>{};
    index.forEach((routeId, line) {
      encoded[routeId] = {
        'routeId': line.routeId,
        'number': line.number,
        'type': line.type.name,
      };
    });
    await file.writeAsString(jsonEncode(encoded));
  }
}
