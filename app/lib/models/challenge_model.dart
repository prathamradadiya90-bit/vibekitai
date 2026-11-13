/// Daily creative challenge model.
class ChallengeModel {
  final String id;
  final String title;
  final String prompt;
  final String targetFeature; // 'reply', 'caption', 'card'
  final String tone;
  final String tag;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.prompt,
    required this.targetFeature,
    required this.tone,
    required this.tag,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as String,
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      targetFeature: json['targetFeature'] as String,
      tone: json['tone'] as String,
      tag: json['tag'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'prompt': prompt,
        'targetFeature': targetFeature,
        'tone': tone,
        'tag': tag,
      };
}
