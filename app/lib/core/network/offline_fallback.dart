import 'dart:math';
import '../../models/generation_models.dart';

/// Provides high-quality, immediate on-device fallback generations
/// when the user is offline, on airplane mode, or network times out.
/// Ensures the user never encounters a blank screen or timeout error card.
class OfflineFallback {
  OfflineFallback._();

  static final Random _rand = Random();

  static ReplyResponse getFallbackReplies(
    ReplyRequest request,
    int remainingCredits,
  ) {
    final tone = request.tone.toLowerCase().trim();
    final lang = request.language.toLowerCase().trim();

    List<String> pool;

    if (lang.contains('hindi') || lang.contains('hinglish')) {
      if (tone.contains('fun') || tone.contains('wit')) {
        pool = [
          "Bhai pehle pizza order kar, phir sochte hain!",
          "Main toh ready hoon, par mera aalas mana kar raha hai.",
          "Scene kya hai pehle clear bata, phir main haan bolunga."
        ];
      } else if (tone.contains('flirt') || tone.contains('rizz')) {
        pool = [
          "Aapne bulaya aur hum na aaye, aisa ho sakta hai kya?",
          "Sirf tab agar party me saari attention mujhe milegi 😉",
          "Itna sweet message karoge toh mana kaise karunga?"
        ];
      } else if (tone.contains('savage')) {
        pool = [
          "Seen pe chhodna hi mera jawab tha, par theek hai.",
          "Mera schedule thoda expensive hai, baad me baat karte hain.",
          "Apne kaam se kaam rakhne me kitna maza aata hai na?"
        ];
      } else {
        pool = [
          "Haan bilkul, plan banate hain!",
          "Thoda busy tha, abhi free hua. Batao kya haal chaal?",
          "Done hai, time aur location bhej do!"
        ];
      }
    } else {
      // English / International
      if (tone.contains('fun')) {
        pool = [
          "Depends, are we talking 'paint the town red' or 'stare blankly at a screen with pizza'?",
          "I'd love to, but my couch and I are in a very committed relationship right now.",
          "Give me 10 minutes to overthink this and I'll confirm."
        ];
      } else if (tone.contains('flirt') || tone.contains('rizz')) {
        pool = [
          "Only if you promise to make it worth my while 😉",
          "I was hoping you'd ask. What did you have in mind?",
          "Was wondering when you were finally gonna make a move."
        ];
      } else if (tone.contains('savage') || tone.contains('unbothered')) {
        pool = [
          "Left on read was my subtle answer, but here we are.",
          "That sounds like a 'you' problem, but good luck with it.",
          "I'm flattered, but I value my peace of mind a bit more."
        ];
      } else if (tone.contains('wit')) {
        pool = [
          "Plot twist: I actually have zero plans and full availability.",
          "You had me at hello, but lost me at having to wear real pants.",
          "Bold of you to assume my social battery is charged, but let's test it."
        ];
      } else if (tone.contains('profess') || tone.contains('polite')) {
        pool = [
          "Thank you for reaching out! Let me check my calendar and get back to you shortly.",
          "I appreciate the note. Let's connect tomorrow morning to coordinate the details.",
          "Thank you so much. Looking forward to touching base soon."
        ];
      } else if (tone.contains('confid')) {
        pool = [
          "Sounds like an opportunity I wouldn't want to miss. Count me in.",
          "Consider it done. I'll take care of everything on my end.",
          "Let's make it happen. I'm ready whenever you are."
        ];
      } else if (tone.contains('support')) {
        pool = [
          "I'm here for you no matter what. Take all the time you need.",
          "You've got this! Rooting for you every single step.",
          "Don't worry about a thing, we will figure it out together."
        ];
      } else if (tone.contains('opener')) {
        pool = [
          "Quick question: what is the most controversial opinion you hold?",
          "Scale of 1-10, how adventurous are you feeling today?",
          "Not to be dramatic, but your profile just made my day."
        ];
      } else {
        // Friendly / Default
        pool = [
          "Hey! Great hearing from you. Absolutely, let's do this!",
          "Sounds like a great plan! What time works best for you?",
          "Always up for a good catch-up. Count me in!"
        ];
      }
    }

    return ReplyResponse(
      suggestions: pool.take(request.count).toList(),
      tone: request.tone,
      language: request.language,
      creditsRemaining: remainingCredits,
    );
  }

  static CaptionResponse getFallbackCaptions(
    CaptionRequest request,
    int remainingCredits,
  ) {
    final topic = request.topic.trim();
    return CaptionResponse(
      captions: [
        "Chasing moments, not things. ✨ When $topic hits just right.",
        "Some days you just have to pause and soak it all in. 🌅 #LivingInTheMoment",
        "If you were waiting for a sign, this is it. Never forget why you started. 🔥",
      ],
      hooks: [
        "Stop scrolling for 3 seconds.",
        "The best part nobody told you about this...",
      ],
      callToActions: [
        "Drop a ❤️ if you agree!",
        "Tag someone who needs this today.",
      ],
      hashtags: [
        "#VibeCheck",
        "#InstaDaily",
        "#Mood",
        "#Trending",
        "#ExplorePage",
        "#PhotoOfTheDay",
      ],
      creditsRemaining: remainingCredits,
    );
  }

  static BioResponse getFallbackBios(
    BioRequest request,
    int remainingCredits,
  ) {
    final interests = request.interests.trim();
    return BioResponse(
      bios: [
        "✨ $interests enthusiast | Creating my own sunshine ☀️ | Always down for a good chat ☕",
        "📍 Living in real time | $interests | Building things that matter 🚀",
        "Just a human trying to navigate life with $interests and good playlists 🎧✨",
      ],
      usernames: [
        "@vibe_${interests.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}",
        "@the_real_${request.vibe.toLowerCase()}",
        "@daily_${request.platform.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}_spark",
        "@crafted_vibes",
        "@neon_aesthetic",
      ],
      creditsRemaining: remainingCredits,
    );
  }

  static VibeCheckResponse getFallbackVibeCheck(
    VibeCheckRequest request,
    int remainingCredits,
  ) {
    return VibeCheckResponse(
      score: 78,
      title: "Strong Energy & Intent",
      verdict:
          "Your message has clear direction and confidence. Adding a touch of personal flair or a specific call-to-action will boost the response rate significantly.",
      tags: ["#Confident", "#ClearIntent", "#HighEngagement"],
      rewrites: [
        "Hey! Quick question: what does your schedule look like this week?",
        "Loved your perspective on that! Let's grab coffee and talk through it.",
        "Thinking of you! Hope your week is off to an amazing start.",
      ],
      creditsRemaining: remainingCredits,
    );
  }
}
