import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import '../models/lesson.dart';

class ExcelParser {
  static List<Lesson>? _cachedLessons;
  static String? _cachedGroupName;
  static int? _cachedSubgroup;
  static List<String>? _cachedGroupsList;

  // Текущий файл расписания в ассетах
  static const String currentExcelPath = "assets/data/Raspisanie_2_sem_2025_2026_ot_03.03.2026.xlsx";

  final List<String> timeSlots = [
    "08:30 - 10:00",
    "10:10 - 11:40",
    "12:10 - 13:40",
    "13:50 - 15:20",
    "15:50 - 17:20",
    "17:30 - 19:00",
    "19:10 - 20:40",
  ];

  Future<List<String>> getGroups() async {
    if (_cachedGroupsList != null) return _cachedGroupsList!;
    try {
      ByteData data = await rootBundle.load(currentExcelPath);
      var excel = Excel.decodeBytes(data.buffer.asUint8List());
      var sheet = excel.tables.values.first;
      Set<String> groups = {};

      for (int col = 0; col < sheet.maxColumns; col++) {
        var val = _getCellValue(sheet, col, 16);
        if (val != null) {
          String s = val.toString().trim();
          // Простая проверка, что это похоже на номер группы (например, 09-332)
          if (s.length >= 5 && (s.contains('-') || s.startsWith('09-'))) {
            groups.add(s);
          }
        }
      }
      _cachedGroupsList = groups.toList()..sort();
      return _cachedGroupsList!;
    } catch (e) {
      print("Ошибка получения списка групп: $e");
      return [];
    }
  }

  Future<List<Lesson>> parseSchedule(String groupName, {int subgroup = 1, bool clearCache = false}) async {
    if (!clearCache && _cachedLessons != null && _cachedGroupName == groupName && _cachedSubgroup == subgroup) {
      return _cachedLessons!;
    }

    List<Lesson> lessons = [];
    try {
      ByteData data = await rootBundle.load(currentExcelPath);
      var excel = Excel.decodeBytes(data.buffer.asUint8List());
      var sheet = excel.tables.values.first;

      int groupColIndex = -1;
      for (int col = 0; col < sheet.maxColumns; col++) {
        var val = _getCellValue(sheet, col, 16);
        if (val != null && val.toString().trim() == groupName) {
          // Обычно подгруппа 1 - это колонка группы, подгруппа 2 - следующая
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
            var startCell = _getMergeStart(sheet, groupColIndex, row);
            var val = sheet.cell(startCell).value;

            if (val != null && val.toString().trim().isNotEmpty) {
              String cellAddress = startCell.toString();
              if (!processedCells.contains(cellAddress)) {
                _addLesson(val.toString(), timeSlots[pairIdx], day + 1, subgroup, lessons);
                processedCells.add(cellAddress);
              }
            }
          }
        }
      }
      _cachedLessons = lessons;
      _cachedGroupName = groupName;
      _cachedSubgroup = subgroup;
    } catch (e) {
      print("Ошибка парсинга группы $groupName: $e");
    }
    return lessons;
  }

  CellIndex _getMergeStart(Sheet sheet, int col, int row) {
    for (var span in sheet.spannedItems) {
      final range = span.toString().split('!').last.replaceAll('\$', '');
      final parts = range.split(':');
      if (parts.length == 2) {
        final start = CellIndex.indexByString(parts[0]);
        final end = CellIndex.indexByString(parts[1]);
        if (row >= start.rowIndex && row <= end.rowIndex &&
            col >= start.columnIndex && col <= end.columnIndex) {
          return start;
        }
      }
    }
    return CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
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

      if (name.isEmpty) {
        name = "Неизвестный предмет (ошибка парсинга)";
      }

      lessons.add(Lesson(
        name: name,
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

  dynamic _getCellValue(Sheet sheet, int col, int row) {
    var startCell = _getMergeStart(sheet, col, row);
    return sheet.cell(startCell).value;
  }
}
