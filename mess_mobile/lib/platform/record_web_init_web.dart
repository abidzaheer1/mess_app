import 'package:record_platform_interface/record_platform_interface.dart';
import 'package:record_web/record_web.dart';

void initRecordWeb() {
  RecordPlatform.instance = RecordPluginWebWrapper();
}
