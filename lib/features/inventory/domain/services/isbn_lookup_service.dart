import 'dart:convert';
import 'dart:io';

/// DTO containing bibliographic metadata retrieved from an external ISBN query.
class BookMetadataResult {
  const BookMetadataResult({
    required this.title,
    this.subtitle,
    required this.author,
    this.additionalAuthors = const [],
    this.publisher = '',
    this.isbn10,
    this.isbn13,
    this.genre = 'General',
    this.language = 'English',
    this.description = '',
    this.coverImageUrl,
  });

  final String title;
  final String? subtitle;
  final String author;
  final List<String> additionalAuthors;
  final String publisher;
  final String? isbn10;
  final String? isbn13;
  final String genre;
  final String language;
  final String description;
  final String? coverImageUrl;
}

/// Service providing offline-safe ISBN and bibliographic book metadata lookups.
///
/// Queries Open Library API as an open, keyless metadata registry.
/// Catches all network/offline exceptions gracefully and returns `null` without throwing.
class IsbnLookupService {
  const IsbnLookupService();

  /// Looks up metadata by ISBN-10 or ISBN-13.
  Future<BookMetadataResult?> lookupByIsbn(String rawIsbn) async {
    final cleaned = rawIsbn.replaceAll(RegExp(r'[^0-9Xx]'), '').trim();
    if (cleaned.length != 10 && cleaned.length != 13) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final uri = Uri.parse(
        'https://openlibrary.org/api/books?bibkeys=ISBN:$cleaned&jscmd=data&format=json',
      );
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody) as Map<String, dynamic>;

      final key = 'ISBN:$cleaned';
      if (!data.containsKey(key)) return null;

      final bookData = data[key] as Map<String, dynamic>;

      final title = bookData['title'] as String? ?? '';
      final subtitle = bookData['subtitle'] as String?;

      // Extract authors
      final authorsList = bookData['authors'] as List<dynamic>? ?? [];
      final authors = authorsList
          .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final primaryAuthor = authors.isNotEmpty
          ? authors.first
          : 'Unknown Author';
      final additionalAuthors = authors.length > 1
          ? authors.sublist(1)
          : <String>[];

      // Extract publishers
      final publishersList = bookData['publishers'] as List<dynamic>? ?? [];
      final publisher = publishersList.isNotEmpty
          ? (publishersList.first as Map<String, dynamic>)['name'] as String? ??
                ''
          : '';

      // Extract cover image
      final covers = bookData['cover'] as Map<String, dynamic>?;
      final coverUrl =
          covers?['large'] as String? ??
          covers?['medium'] as String? ??
          covers?['small'] as String?;

      // Extract subjects/genre
      final subjects = bookData['subjects'] as List<dynamic>? ?? [];
      final genre = subjects.isNotEmpty
          ? (subjects.first as Map<String, dynamic>)['name'] as String? ??
                'General'
          : 'General';

      return BookMetadataResult(
        title: title,
        subtitle: subtitle,
        author: primaryAuthor,
        additionalAuthors: additionalAuthors,
        publisher: publisher,
        isbn10: cleaned.length == 10 ? cleaned : null,
        isbn13: cleaned.length == 13 ? cleaned : null,
        genre: genre,
        coverImageUrl: coverUrl,
      );
    } catch (_) {
      // Offline or network error - return null gracefully
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
