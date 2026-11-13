library;

/// Data transfer contracts for AI generations (Reply & Caption).

class ReplyRequest {
  final String message;
  final String tone;
  final String language;
  final String length; // short, medium, detailed
  final int count;

  const ReplyRequest({
    required this.message,
    required this.tone,
    required this.language,
    this.length = 'medium',
    this.count = 3,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'tone': tone,
        'language': language,
        'length': length,
        'count': count,
      };
}

class ReplyResponse {
  final List<String> suggestions;
  final String tone;
  final String language;
  final int creditsRemaining;

  const ReplyResponse({
    required this.suggestions,
    required this.tone,
    required this.language,
    required this.creditsRemaining,
  });

  factory ReplyResponse.fromJson(Map<String, dynamic> json) {
    final list = json['suggestions'] as List<dynamic>? ?? [];
    return ReplyResponse(
      suggestions: list.map((e) => e.toString()).toList(),
      tone: (json['tone'] as String?) ?? '',
      language: (json['language'] as String?) ?? '',
      creditsRemaining: (json['credits_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class CaptionRequest {
  final String topic;
  final String
      platform; // Instagram, Reels, WhatsApp Status, YouTube Shorts, General
  final String tone;
  final String language;
  final String length; // short, medium, detailed
  final bool includeHooks;
  final bool includeHashtags;

  const CaptionRequest({
    required this.topic,
    required this.platform,
    required this.tone,
    required this.language,
    this.length = 'medium',
    this.includeHooks = true,
    this.includeHashtags = true,
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'platform': platform,
        'tone': tone,
        'language': language,
        'length': length,
        'include_hooks': includeHooks,
        'include_hashtags': includeHashtags,
      };
}

class CaptionResponse {
  final List<String> captions;
  final List<String> hooks;
  final List<String> callToActions;
  final List<String> hashtags;
  final int creditsRemaining;

  const CaptionResponse({
    required this.captions,
    required this.hooks,
    required this.callToActions,
    required this.hashtags,
    required this.creditsRemaining,
  });

  factory CaptionResponse.fromJson(Map<String, dynamic> json) {
    final caps = (json['captions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final hks =
        (json['hooks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            [];
    final ctas = (json['call_to_actions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final tags = (json['hashtags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return CaptionResponse(
      captions: caps,
      hooks: hks,
      callToActions: ctas,
      hashtags: tags,
      creditsRemaining: (json['credits_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class BioRequest {
  final String interests;
  final String platform;
  final String vibe;
  final String language;
  final bool includeUsernames;

  const BioRequest({
    required this.interests,
    required this.platform,
    required this.vibe,
    required this.language,
    this.includeUsernames = true,
  });

  Map<String, dynamic> toJson() => {
        'interests': interests,
        'platform': platform,
        'vibe': vibe,
        'language': language,
        'include_usernames': includeUsernames,
      };
}

class BioResponse {
  final List<String> bios;
  final List<String> usernames;
  final int creditsRemaining;

  const BioResponse({
    required this.bios,
    required this.usernames,
    required this.creditsRemaining,
  });

  factory BioResponse.fromJson(Map<String, dynamic> json) {
    final bioList = (json['bios'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final usernameList = (json['usernames'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return BioResponse(
      bios: bioList,
      usernames: usernameList,
      creditsRemaining: (json['credits_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class VibeCheckRequest {
  final String text;
  final String mode; // roast, polish, dating, work
  final String language;

  const VibeCheckRequest({
    required this.text,
    this.mode = 'roast',
    this.language = 'English',
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'mode': mode,
        'language': language,
      };
}

class VibeCheckResponse {
  final int score;
  final String title;
  final String verdict;
  final List<String> tags;
  final List<String> rewrites;
  final int creditsRemaining;

  const VibeCheckResponse({
    required this.score,
    required this.title,
    required this.verdict,
    required this.tags,
    required this.rewrites,
    required this.creditsRemaining,
  });

  factory VibeCheckResponse.fromJson(Map<String, dynamic> json) {
    final tagList = (json['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final rewriteList = (json['rewrites'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return VibeCheckResponse(
      score: (json['score'] as num?)?.toInt() ?? 50,
      title: (json['title'] as String?) ?? 'Vibe Check',
      verdict: (json['verdict'] as String?) ?? '',
      tags: tagList,
      rewrites: rewriteList,
      creditsRemaining: (json['credits_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
