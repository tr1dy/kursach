import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/lesson.dart';

class ExcelParser {
  final List<String> timeSlots = [
    "08:30 - 10:00",
    "10:10 - 11:40",
    "12:10 - 13:40",
    "13:50 - 15:20",
    "15:50 - 17:20",
    "17:30 - 19:00",
    "19:10 - 20:40",
  ];

  // Кеш для объединенных ячеек текущего листа
  Map<String, CellIndex>? _spansCache;

  Excel decode(Uint8List bytes) {
    return Excel.decodeBytes(bytes);
  }

  // Подготавливаем кеш объединений для конкретного листа
  void _prepareSpansCache(Sheet sheet) {
    _spansCache = {};
    for (var span in sheet.spannedItems) {
      final range = span.toString().split('!').last.replaceAll('\$', '');
      final parts = range.split(':');
      
      if (parts.length == 2) {
        final start = CellIndex.indexByString(parts[0]);
        final end = CellIndex.indexByString(parts[1]);
        
        for (int r = start.rowIndex; r <= end.rowIndex; r++) {
          for (int c = start.columnIndex; c <= end.columnIndex; c++) {
            _spansCache!["$c-$r"] = start;
          }
        }
      }
    }
  }

  CellIndex _getMergeStartFast(int col, int row) {
    return _spansCache?["$col-$row"] ?? CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
  }

  List<String> getGroupsFromExcel(Excel excel) {
    try {
      var sheet = excel.tables.values.first;
      Set<String> groups = {};

      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 16));
        var val = cell.value;
        if (val != null) {
          String s = val.toString().trim();
          if (s.length >= 5 && (s.contains('-') || s.startsWith('09-'))) {
            groups.add(s);
          }
        }
      }
      return groups.toList()..sort();
    } catch (e) {
      print("Ошибка получения групп: $e");
      return [];
    }
  }

  List<Lesson> parseScheduleFromExcel(Excel excel, String groupName, {int subgroup = 1}) {
    List<Lesson> lessons = [];
    try {
      var sheet = excel.tables.values.first;
      
      if (_spansCache == null) {
        _prepareSpansCache(sheet);
      }

      int groupColIndex = -1;
      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 16));
        if (cell.value != null && cell.value.toString().trim() == groupName) {
          groupColIndex = col + (subgroup - 1);
          break;
        }
      }

      if (groupColIndex == -1) return [];

      for (int day = 0; day < 6; day++) {
        int dayStartRow = 17 + (day * 15);
        Set<String> processedCells = {};

        for (int pairIdx = 0; pairIdx < 7; pairIdx++) {
          int r1 = dayStartRow + (pairIdx * 2);
          int r2 = r1 + 1;

          for (int row in [r1, r2]) {
            var startCell = _getMergeStartFast(groupColIndex, row);
            var cellValue = sheet.cell(startCell).value;

            if (cellValue != null && cellValue.toString().trim().isNotEmpty) {
              String cellAddress = "${startCell.columnIndex}-${startCell.rowIndex}";
              if (!processedCells.contains(cellAddress)) {
                _addLesson(cellValue.toString(), timeSlots[pairIdx], day + 1, subgroup, lessons);
                processedCells.add(cellAddress);
              }
            }
          }
        }
      }
    } catch (e) {
      print("Ошибка парсинга группы $groupName: $e");
    }
    return lessons;
  }

  void clearCache() {
    _spansCache = null;
  }

  void _addLesson(String rawText, String time, int day, int sub, List<Lesson> lessons) {
    List<String> rawParts = rawText.split(';');
    for (String part in rawParts) {
      String text = part.replaceAll('\n', ' ').trim();
      if (text.length < 3) continue;

      final weekRegex = RegExp(r'\(([^)]*нед\.[^)]*)\)');
      final teacherRegex = RegExp(r'([А-ЯЁ][а-яё]+\s+[А-ЯЁ]\.\s?[А-ЯЁ]\.)');
      final roomRegex = RegExp(r'(ауд\.\s*.*)');

      String weeks = "";
      String teacher = "";
      String room = "";
      String name = text;

      final weekMatch = weekRegex.firstMatch(name);
      if (weekMatch != null) {
        weeks = weekMatch.group(0)!;
        name = name.replaceFirst(weeks, '').trim();
      }

      final roomMatch = roomRegex.firstMatch(name);
      if (roomMatch != null) {
        room = roomMatch.group(0)!;
        name = name.replaceFirst(room, '').trim();
      }

      final teacherMatch = teacherRegex.firstMatch(name);
      if (teacherMatch != null) {
        teacher = teacherMatch.group(0)!;
        name = name.replaceFirst(teacher, '').trim();
      }

      name = name.replaceAll(RegExp(r'[,.\s]+$'), '').trim();
      name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

      String lowerText = text.toLowerCase();
      WeekType type = WeekType.both;
      if (lowerText.contains('н/н') || lowerText.contains('нечет')) {
        type = WeekType.odd;
      } else if (lowerText.contains('ч/н') || lowerText.contains('чет')) {
        type = WeekType.even;
      }

      lessons.add(Lesson(
        name: name.isEmpty ? "Неизвестный предмет" : name,
        teacher: teacher,
        room: room,
        weeks: weeks,
        time: time,
        dayOfWeek: day,
        weekType: type,
        subgroup: sub,
        rawText: text,
      ));
    }
  }
}
