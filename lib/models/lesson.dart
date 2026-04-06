enum WeekType { odd, even, both }

class Lesson {
  final String name;
  final String teacher;
  final String room;
  final String time;
  final int dayOfWeek;
  final WeekType weekType;
  final int subgroup;
  final String weeks;

  Lesson({
    required this.name,
    required this.teacher,
    required this.room,
    required this.time,
    required this.dayOfWeek,
    required this.weekType,
    required this.subgroup,
    this.weeks = "",
  });
}
