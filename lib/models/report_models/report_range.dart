part of '../../providers/report_provider.dart';

@immutable
class ReportRange {
  final DateTime? startDate;
  final DateTime? endDate;
  const ReportRange({this.startDate, this.endDate});
}
