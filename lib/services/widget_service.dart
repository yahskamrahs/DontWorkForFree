import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const _androidName = 'ShiftWidgetReceiver';
  static const _qualifiedName = 'com.example.my_app.ShiftWidgetReceiver';

  static Future<void> update({
    required bool isActive,
    required String remaining,
    required String exitTime,
  }) async {
    await HomeWidget.saveWidgetData<String>('widget_remaining', remaining);
    await HomeWidget.saveWidgetData<String>(
      'widget_exit_time',
      isActive ? 'Safe exit: $exitTime' : 'Safe exit: --',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_status',
      isActive ? 'SHIFT ACTIVE' : 'NO SHIFT',
    );
    await HomeWidget.updateWidget(
      name: _androidName,
      qualifiedAndroidName: _qualifiedName,
    );
  }

  static Future<void> clear() async {
    await HomeWidget.saveWidgetData<String>('widget_remaining', '--:--:--');
    await HomeWidget.saveWidgetData<String>('widget_exit_time', 'Safe exit: --');
    await HomeWidget.saveWidgetData<String>('widget_status', 'NO SHIFT');
    await HomeWidget.updateWidget(
      name: _androidName,
      qualifiedAndroidName: _qualifiedName,
    );
  }
}
