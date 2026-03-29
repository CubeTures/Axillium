import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_user.dart';

class LocalStorageService {
  static const _aliasKey = 'alias';
  static const _rankKey = 'rank';
  static const _userIdKey = 'user_id';
  static const _locationKey = 'location';
  static const _addictionTypeKey = 'addiction_type';
  static const _groupIdKey = 'group_id';
  static const _isLeaderKey = 'is_leader';
  static const _sponsorIdKey = 'sponsor_id';
  static const _profilePictureKey = 'profile_picture';

  Future<LocalUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final alias = prefs.getString(_aliasKey);
    if (alias == null) return null;
    final rawSponsorId = prefs.getInt(_sponsorIdKey);
    final pic = prefs.getString(_profilePictureKey);
    return LocalUser(
      alias: alias,
      rank: prefs.getString(_rankKey) ?? 'anonymous',
      userId: prefs.getInt(_userIdKey),
      location: prefs.getString(_locationKey),
      addictionType: prefs.getString(_addictionTypeKey),
      groupId: prefs.getInt(_groupIdKey),
      isLeader: prefs.getBool(_isLeaderKey) ?? false,
      sponsorId: (rawSponsorId != null && rawSponsorId > 0) ? rawSponsorId : null,
      profilePicture: (pic != null && pic.isNotEmpty) ? pic : null,
    );
  }

  Future<LocalUser> completeOnboarding({
    required String alias,
    required String location,
    String? addictionType,
    int? groupId,
    bool isLeader = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final effective = alias.trim().isEmpty ? 'Anonymous' : alias.trim();
    await prefs.setString(_aliasKey, effective);
    await prefs.setString(_rankKey, 'anonymous');
    await prefs.setString(_locationKey, location.trim());
    if (addictionType != null) await prefs.setString(_addictionTypeKey, addictionType);
    if (groupId != null) await prefs.setInt(_groupIdKey, groupId);
    await prefs.setBool(_isLeaderKey, isLeader);
    return LocalUser(
      alias: effective,
      rank: 'anonymous',
      location: location.trim(),
      addictionType: addictionType,
      groupId: groupId,
      isLeader: isLeader,
    );
  }

  Future<void> saveLocationAndCommunity({
    required String location,
    String? addictionType,
    int? groupId,
    bool isLeader = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, location.trim());
    if (addictionType != null) await prefs.setString(_addictionTypeKey, addictionType);
    if (groupId != null) await prefs.setInt(_groupIdKey, groupId);
    await prefs.setBool(_isLeaderKey, isLeader);
  }

  Future<int?> getGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_groupIdKey);
  }

  /// Saves registration data after a successful login or register API call.
  /// [role] comes from the API response and determines the stored rank and isLeader flag.
  Future<LocalUser> saveRegistration(
    int userId,
    String alias, {
    int? groupId,
    String role = 'apprentice',
    int? sponsorId,
    String? addictionType,
    String? profilePicture,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_aliasKey, alias);
    await prefs.setString(_rankKey, role);
    final isLeader = role == 'leader';
    await prefs.setBool(_isLeaderKey, isLeader);
    final effectiveGroupId = groupId ?? prefs.getInt(_groupIdKey);
    if (effectiveGroupId != null) await prefs.setInt(_groupIdKey, effectiveGroupId);
    final effectiveSponsorId = sponsorId != null && sponsorId > 0 ? sponsorId : null;
    if (effectiveSponsorId != null) await prefs.setInt(_sponsorIdKey, effectiveSponsorId);
    // Addiction type comes from the group — overwrite if the backend provided it
    final effectiveAddictionType = addictionType ?? prefs.getString(_addictionTypeKey);
    if (effectiveAddictionType != null) {
      await prefs.setString(_addictionTypeKey, effectiveAddictionType);
    }
    final effectivePic = (profilePicture != null && profilePicture.isNotEmpty)
        ? profilePicture
        : prefs.getString(_profilePictureKey);
    if (effectivePic != null && effectivePic.isNotEmpty) {
      await prefs.setString(_profilePictureKey, effectivePic);
    }
    return LocalUser(
      alias: alias,
      rank: role,
      userId: userId,
      location: prefs.getString(_locationKey),
      addictionType: effectiveAddictionType,
      groupId: effectiveGroupId,
      isLeader: isLeader,
      sponsorId: effectiveSponsorId,
      profilePicture: effectivePic,
    );
  }

  Future<LocalUser> saveSponsorId(int sponsorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sponsorIdKey, sponsorId);
    return LocalUser(
      alias: prefs.getString(_aliasKey) ?? 'Anonymous',
      rank: prefs.getString(_rankKey) ?? 'anonymous',
      userId: prefs.getInt(_userIdKey),
      location: prefs.getString(_locationKey),
      addictionType: prefs.getString(_addictionTypeKey),
      groupId: prefs.getInt(_groupIdKey),
      isLeader: prefs.getBool(_isLeaderKey) ?? false,
      sponsorId: sponsorId,
    );
  }

  Future<LocalUser> clearSponsorId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sponsorIdKey);
    return LocalUser(
      alias: prefs.getString(_aliasKey) ?? 'Anonymous',
      rank: prefs.getString(_rankKey) ?? 'anonymous',
      userId: prefs.getInt(_userIdKey),
      location: prefs.getString(_locationKey),
      addictionType: prefs.getString(_addictionTypeKey),
      groupId: prefs.getInt(_groupIdKey),
      isLeader: prefs.getBool(_isLeaderKey) ?? false,
      sponsorId: null,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
