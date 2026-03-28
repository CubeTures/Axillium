import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_user.dart';

class LocalStorageService {
  static const _aliasKey = 'alias';
  static const _rankKey = 'rank';
  static const _userIdKey = 'user_id';
  static const _groupIdKey = 'group_id';

  Future<LocalUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final alias = prefs.getString(_aliasKey);
    if (alias == null) return null; // not yet onboarded
    final rank = prefs.getString(_rankKey) ?? 'anonymous';
    final userId = prefs.getInt(_userIdKey);
    final groupId = prefs.getInt(_groupIdKey);
    return LocalUser(alias: alias, rank: rank, userId: userId, groupId: groupId);
  }

  Future<LocalUser> completeOnboarding(String alias) async {
    final prefs = await SharedPreferences.getInstance();
    final effective = alias.trim().isEmpty ? 'Anonymous' : alias.trim();
    await prefs.setString(_aliasKey, effective);
    await prefs.setString(_rankKey, 'anonymous');
    return LocalUser(alias: effective, rank: 'anonymous');
  }

  Future<LocalUser> saveRegistration(int userId, String alias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_aliasKey, alias);
    await prefs.setString(_rankKey, 'apprentice');
    await prefs.setInt(_groupIdKey, 1);
    return LocalUser(alias: alias, rank: 'apprentice', userId: userId, groupId: 1);
  }

  Future<LocalUser> debugSetRank(LocalUser current, String rank) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rankKey, rank);
    return current.copyWith(rank: rank);
  }

  Future<LocalUser> debugSwitchAccount(LocalUser account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aliasKey, account.alias);
    await prefs.setString(_rankKey, account.rank);
    if (account.userId != null) {
      await prefs.setInt(_userIdKey, account.userId!);
    } else {
      await prefs.remove(_userIdKey);
    }
    if (account.groupId != null) {
      await prefs.setInt(_groupIdKey, account.groupId!);
    } else {
      await prefs.remove(_groupIdKey);
    }
    return account;
  }
}
