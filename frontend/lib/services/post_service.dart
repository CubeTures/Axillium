import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post.dart';

class PostService {
  static const String _base = 'http://10.0.2.2:8080/api';

  Future<Post> getPost(int id) async {
    final response = await http.get(Uri.parse('$_base/posts/$id'));
    if (response.statusCode == 200) {
      return Post.fromJson(jsonDecode(response.body));
    }
    throw Exception('Post not found');
  }

  Future<List<Post>> getGroupFeaturedPosts(int groupId) async {
    final response =
        await http.get(Uri.parse('$_base/groups/$groupId/featured-posts'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Post.fromJson(e)).toList();
    }
    throw Exception('Failed to load featured posts');
  }

  Future<void> featurePostForGroup({
    required int groupId,
    required int postId,
    required int featurerId,
    required String featurerRole,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/groups/$groupId/featured-posts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'post_id': postId,
        'featurer_id': featurerId,
        'featurer_role': featurerRole,
      }),
    );
    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['error'] ?? 'Failed to feature post';
      throw Exception(error);
    }
  }

  Future<void> unfeaturePostForGroup({
    required int groupId,
    required int postId,
    required String featurerRole,
  }) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$_base/groups/$groupId/featured-posts/$postId'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'featurer_role': featurerRole});
    final streamed = await request.send();
    if (streamed.statusCode != 200) {
      throw Exception('Failed to unfeature post');
    }
  }

  Future<List<Post>> getPosts({
    int page = 1,
    String? addictionType,
    String? title,
  }) async {
    final params = {'page': '$page'};
    if (addictionType != null && addictionType.isNotEmpty) {
      params['addiction_type'] = addictionType;
    }
    if (title != null && title.isNotEmpty) params['title'] = title;
    final uri = Uri.parse('$_base/posts').replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Post.fromJson(e)).toList();
    }
    throw Exception('Failed to load posts');
  }

  Future<Post> createPost({
    required int authorId,
    required String authorAlias,
    required String authorRole,
    required String addictionType,
    required String title,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/posts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'author_id': authorId,
        'author_alias': authorAlias,
        'author_role': authorRole,
        'addiction_type': addictionType,
        'title': title,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      return Post.fromJson(jsonDecode(response.body));
    }
    final error = jsonDecode(response.body)['error'] ?? 'Failed to create post';
    throw Exception(error);
  }
}
