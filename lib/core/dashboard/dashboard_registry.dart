import 'dashboard_widget.dart';

class DashboardRegistry {
  DashboardRegistry._();

  static final DashboardRegistry instance =
      DashboardRegistry._();

  final List<DashboardWidget> _widgets = [];

  List<DashboardWidget> get widgets =>
      List.unmodifiable(_widgets);

  void register(
    DashboardWidget widget,
  ) {
    _widgets.add(widget);
  }

  void clear() {
    _widgets.clear();
  }
}