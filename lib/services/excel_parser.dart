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
      final range = span
          .toString()
          .split('!')
          .last
          .replaceAll('\$', '');
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
    return _spansCache?["$col-$row"] ??
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
  }

  String _cleanGroupName(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*\(\d+\).*$'), '') // Убирает " (1)" или "(2)"
        .replaceAll(RegExp(r'\s+\d+\s*подгр.*$', caseSensitive: false),
        '') // Убирает " 1 подгруппа"
        .trim();
  }

  List<String> getGroupsFromExcel(Excel excel) {
    try {
      var sheet = excel.tables.values.first;
      Set<String> groups = {};

      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 16));
        var val = cell.value;
        if (val != null) {
          String s = val.toString().trim();
          if (s.length >= 5 && (s.contains('-') || s.startsWith('09-'))) {
            groups.add(_cleanGroupName(s));
          }
        }
      }
      return groups.toList()
        ..sort();
    } catch (e) {
      print("Ошибка получения групп: $e");
      return [];
    }
  }

  List<Lesson> parseScheduleFromExcel(Excel excel, String groupName,
      {int subgroup = 1}) {
    List<Lesson> lessons = [];
    try {
      var sheet = excel.tables.values.first;

      if (_spansCache == null) {
        _prepareSpansCache(sheet);
      }

      int groupColIndex = -1;
      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 16));
        if (cell.value != null) {
          String cellValue = cell.value.toString().trim();
          if (_cleanGroupName(cellValue) == groupName) {
            groupColIndex = col + (subgroup - 1);
            break;
          }
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
            var cellValue = sheet
                .cell(startCell)
                .value;

            if (cellValue != null && cellValue
                .toString()
                .trim()
                .isNotEmpty) {
              String cellAddress = "${startCell.columnIndex}-${startCell
                  .rowIndex}";
              if (!processedCells.contains(cellAddress)) {
                _addLesson(
                    cellValue.toString(), timeSlots[pairIdx], day + 1, subgroup,
                    lessons);
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

  void _addLesson(String rawText, String time, int day, int sub,
      List<Lesson> lessons) {
    // 1. Заменяем переносы строки и двойные слеши (встречаются в таблице) на точку с запятой
    String cleanText = rawText
        .replaceAll('\n', ';')
        .replaceAll('//', ';')
        .trim();

    List<String> rawParts = cleanText.split(';');

    // Переменные для "наследования" контекста между разделенными кусками
    String lastWeeks = "";
    String lastSubject = "";

    for (String part in rawParts) {
      String text = part.trim();
      if (text.length < 3) continue;

      // Умные регулярки
      // Ищет: "(1-9 нед.)", "1-5н", "(1-17 неделя)", "(ч/н 2-16 нед)" со скобками и без
      final weekRegex = RegExp(
          r'\(?(?:[нч]/н\s*)?\d+(?:-\d+)?\s*(?:нед\.?|н\.?|неделя)[^)]*\)?',
          caseSensitive: false);

      // Ищет стандартные ФИО, перечисления через запятую, а также исключения (Мансур Нур, Панищев)
      final teacherRegex = RegExp(
          r'([А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)?\s+[А-ЯЁ]\.\s?[А-ЯЁ]\.(?:\s*,\s*[А-ЯЁ][а-яё]+\s+[А-ЯЁ]\.\s?[А-ЯЁ]\.)*|Мансур Нур|Панищев)');

      // Ищет аудитории, СЦ (Спортивный центр) и Шахматный центр
      final roomRegex = RegExp(r'((?:ауд\.|Шахматный центр|(?:\s|^)СЦ\s*\(?).*)', caseSensitive: false);

      String weeks = "";
      String teacher = "";
      String room = "";
      String name = text;

      // 1. Парсим недели
      final weekMatch = weekRegex.firstMatch(name);
      if (weekMatch != null) {
        weeks = weekMatch.group(0)!;
        name = name.replaceFirst(weeks, '').trim();
        lastWeeks = weeks; // Запоминаем для следующих частей после ";"
      } else {
        weeks = lastWeeks; // Наследуем от предыдущего куска
      }

      // 2. Парсим аудиторию
      final roomMatch = roomRegex.firstMatch(name);
      if (roomMatch != null) {
        room = roomMatch.group(0)!;
        name = name.replaceFirst(roomMatch.group(0)!, '').trim();
      }

      // 3. Парсим преподавателя
      final teacherMatch = teacherRegex.firstMatch(name);
      if (teacherMatch != null) {
        teacher = teacherMatch.group(0)!;
        name = name.replaceFirst(teacherMatch.group(0)!, '').trim();
      }

      // 4. Очистка мусора в названии (лишние запятые, тире, двоеточия на концах)
      name = name.replaceAll(RegExp(r'[,.\s:-]+$'), '').replaceFirst(
          RegExp(r'^\s*[-:]\s*'), '').trim();
      name = name.replaceAll(RegExp(r'\s{2,}'), ' ');

      // 5. Логика наследования предмета
      if (name.isEmpty || name.toLowerCase() == 'лек.' ||
          name.toLowerCase() == 'пр.' || name.toLowerCase() == 'лаб.') {
        // Если после вырезания остался только тип занятия или пустота, берем предмет из прошлой части
        name = lastSubject + (name.isNotEmpty ? ' ($name)' : '');
      } else {
        lastSubject = name; // Запоминаем нормальный предмет
      }

      if (name.isEmpty) name = "Неизвестный предмет";

      // 6. Определяем четность
      String lowerText = text.toLowerCase();
      WeekType type = WeekType.both;
      if (lowerText.contains('н/н') || lowerText.contains('нечет')) {
        type = WeekType.odd;
      } else if (lowerText.contains('ч/н') || lowerText.contains('чет')) {
        type = WeekType.even;
      }

      if (name.trim().isEmpty || name == "Неизвестный предмет" || name.length < 3) {
        name = text.trim(); // text - это сырая строка до обработки регулярками
        // Очищаем остальные поля, так как они могут содержать мусор, если парсер ошибся
        teacher = "";
        room = "";
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
}
//   void _addLesson(String rawText, String time, int day, int sub, List<Lesson> lessons) {
//     List<String> rawParts = rawText.split(';');
//     for (String part in rawParts) {
//       String text = part.replaceAll('\n', ' ').trim();
//       if (text.length < 3) continue;
//
//       final weekRegex = RegExp(r'\(([^)]*нед\.[^)]*)\)');
//       final teacherRegex = RegExp(r'([А-ЯЁ][а-яё]+\s+[А-ЯЁ]\.\s?[А-ЯЁ]\.)');
//       final roomRegex = RegExp(r'(ауд\.\s*.*)');
//
//       String weeks = "";
//       String teacher = "";
//       String room = "";
//       String name = text;
//
//       final weekMatch = weekRegex.firstMatch(name);
//       if (weekMatch != null) {
//         weeks = weekMatch.group(0)!;
//         name = name.replaceFirst(weeks, '').trim();
//       }
//
//       final roomMatch = roomRegex.firstMatch(name);
//       if (roomMatch != null) {
//         room = roomMatch.group(0)!;
//         name = name.replaceFirst(room, '').trim();
//       }
//
//       final teacherMatch = teacherRegex.firstMatch(name);
//       if (teacherMatch != null) {
//         teacher = teacherMatch.group(0)!;
//         name = name.replaceFirst(teacher, '').trim();
//       }
//
//       name = name.replaceAll(RegExp(r'[,.\s]+$'), '').trim();
//       name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
//
//       String lowerText = text.toLowerCase();
//       WeekType type = WeekType.both;
//       if (lowerText.contains('н/н') || lowerText.contains('нечет')) {
//         type = WeekType.odd;
//       } else if (lowerText.contains('ч/н') || lowerText.contains('чет')) {
//         type = WeekType.even;
//       }
//
//       lessons.add(Lesson(
//         name: name.isEmpty ? "Неизвестный предмет" : name,
//         teacher: teacher,
//         room: room,
//         weeks: weeks,
//         time: time,
//         dayOfWeek: day,
//         weekType: type,
//         subgroup: sub,
//         rawText: text,
//       ));
//     }
//   }
// }
