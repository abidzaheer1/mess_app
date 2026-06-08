import '../models/app_models.dart';

/// True when this user can manage mess settings (member admin, user doc admin, or creator).
bool isMessAdmin({
  required String uid,
  UserProfile? profile,
  Member? member,
  Mess? mess,
}) {
  if (member?.role == Roles.admin) return true;
  if (profile?.role == Roles.admin) return true;
  if (mess != null && mess.createdBy == uid) return true;
  return false;
}
