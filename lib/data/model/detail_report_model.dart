class DetailedReportModel {
  final String dateRange;
  final List<String> symptoms;
  final List<String> triggers;
  final String severity;
  final List<ManagementTip> tips;

  DetailedReportModel({
    required this.dateRange,
    required this.symptoms,
    required this.triggers,
    required this.severity,
    required this.tips,
  });
}

class ManagementTip {
  final String title;
  final List<String> suggestions;

  ManagementTip({required this.title, required this.suggestions});
}
