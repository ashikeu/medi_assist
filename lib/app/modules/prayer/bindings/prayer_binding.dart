import 'package:get/get.dart';
import '../controllers/prayer_controller.dart';

class PrayerBinding extends Bindings {
  @override
  void dependencies() {
    // fenix so the controller survives being popped and rebuilt: the prayer
    // screens navigate between each other freely, and a plain lazyPut would
    // leave a disposed controller behind once the first of them is closed.
    Get.lazyPut<PrayerController>(() => PrayerController(), fenix: true);
  }
}
