class CourseInfo {
  final String teachingClassId;
  final String courseName;
  final String teacherName;
  final String teachingPlace;
  final String classTime;
  final String classType;
  final String courseTypeCode;
  String campus;

  CourseInfo({
    required this.teachingClassId,
    required this.courseName,
    required this.teacherName,
    required this.teachingPlace,
    this.classTime = '',
    this.courseTypeCode = '',
    required this.classType,
    this.campus = '',
  });

  factory CourseInfo.fromJson(Map<String, dynamic> json) => CourseInfo(
        teachingClassId: json['teachingClassId'] ?? '',
        courseName: json['courseName'] ?? '',
        teacherName: json['teacherName'] ?? '',
        teachingPlace: json['teachingPlace'] ?? '',
        classTime: json['classTime'] ?? '',
        courseTypeCode: json['courseTypeCode'] ?? '',
        classType: json['classType'] ?? '',
        campus: json['campus'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'teachingClassId': teachingClassId,
        'courseName': courseName,
        'teacherName': teacherName,
        'teachingPlace': teachingPlace,
        'classTime': classTime,
        'classType': classType,
        'campus': campus,
      };
}

class BatchInfo {
  final String code;
  final String name;
  final String canSelect;

  BatchInfo({required this.code, required this.name, required this.canSelect});

  factory BatchInfo.fromJson(Map<String, dynamic> json) => BatchInfo(
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        canSelect: json['canSelect'] ?? '0',
      );
}

class SelectionStatus {
  final bool running;
  final int totalCourse;
  final List<int> flags;
  final int progress;
  final List<String> log;

  SelectionStatus({
    required this.running,
    required this.totalCourse,
    required this.flags,
    required this.progress,
    required this.log,
  });

  factory SelectionStatus.fromJson(Map<String, dynamic> json) =>
      SelectionStatus(
        running: json['running'] ?? false,
        totalCourse: json['totalCourse'] ?? 0,
        flags: List<int>.from(json['flags'] ?? []),
        progress: json['progress'] ?? 0,
        log: List<String>.from(json['log'] ?? []),
      );
}
