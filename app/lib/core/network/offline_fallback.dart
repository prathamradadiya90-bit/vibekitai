import '../../models/generation_models.dart';

/// Provides high-quality, immediate on-device fallback generations
/// when the user is offline, on airplane mode, or network times out.
/// Honors both the selected language (English, Hindi, Hinglish, Gujarati)
/// and selected tone / vibe / mode options.
class OfflineFallback {
  OfflineFallback._();

  static const Map<String, Map<String, List<String>>> _localizedReplies = {
    'gujarati': {
      'funny': [
        'જમવાનું હોય તો પાક્કું આવું છું, મારી પ્રાથમિકતા ક્લિયર છે 😄',
        'મારો પલંગ મને છોડવા તૈયાર નથી, પણ તારા માટે વિચારી શકું',
        'ચંપલ પહેરું જ છું, બસ આવી ગયો સમજ',
      ],
      'friendly': [
        'હા પાક્કું! કેટલા વાગે મળવું છે?',
        'ચોક્કસ આવીશ, કંઈ લાવવાનું હોય તો કહેજે',
        'કામ પતાવીને તરત મેસેજ કરું છું!',
      ],
      'flirty': [
        'તું હોઈશ તો ચોક્કસ આવીશ 😉',
        'પહેલાં કહે, મારા માટે ખાસ જગ્યા રાખી છે ને?',
        'તેં આટલા પ્રેમથી પૂછ્યું છે તો ના કેમ પાડું',
      ],
      'rizz': [
        'તારો મેસેજ જોઈને આખો દિવસ બની ગયો ✨',
        'કોફી મારી તરફથી, જો તારું પ્લેલિસ્ટ સારું નીકળે તો',
        'તને મેસેજ કરવાનું બહાનું જ શોધતો હતો',
      ],
      'savage': [
        'જેટલી વારમાં રિપ્લાય આવ્યો એટલી વારમાં તો મોસમ બદલાઈ જાય 👀',
        'બસ તમારી જ એનર્જી મેચ કરું છું',
        'કીબોર્ડમાં બીજા અક્ષરો પણ છે, ક્યારેક ટ્રાય કરજો',
      ],
      'unbothered': [
        'વાંધો નહીં, ફ્રી થાઓ ત્યારે જણાવજો.',
        'બધું શાંતિથી પતાવી લો, કોઈ ઉતાવળ નથી.',
        'બરાબર છે, સમય મળે ત્યારે વાત કરીએ.',
      ],
      'confident': [
        'આવું છું, લોકેશન મોકલી દે.',
        'પાક્કું, નક્કી સમયે મળીએ છીએ.',
        'પ્લાન ફાઇનલ સમજો, હું પહોંચી જઈશ.',
      ],
      'professional': [
        'માહિતી બદલ આભાર, હું સાંજ સુધીમાં કન્ફર્મ કરીશ.',
        'હા, મારા માટે અનુકૂળ છે. કૃપા કરીને વિગતો શેર કરશો?',
        'નોંધ લીધી છે. હું અપડેટ સાથે જોડાઈશ.',
      ],
      'polite': [
        'પૂછવા બદલ આભાર! આવવાનો પૂરો પ્રયત્ન કરીશ.',
        'ખૂબ સરસ, એકવાર શેડ્યૂલ જોઈને તરત કહું છું.',
        'ચોક્કસ, એક નાનું કામ પતાવીને તમને જણાવું?',
      ],
      'supportive': [
        'ચિંતા ન કરીશ, વાત કરવી હોય તો હું હંમેશા અહીં છું.',
        'બધું આજે જ ઠીક કરવું જરૂરી નથી, તું સરસ પ્રયત્ન કરે છે.',
        'હું તારી સાથે છું, આરામથી સંભાળી લઈશું.',
      ],
      'witty': [
        'કેલેન્ડરને પૂછ્યું, આખું સાંભળ્યા વગર હા પાડી દીધી',
        'આમંત્રણ છે કે ચેલેન્જ? બંનેમાં મારી હા છે',
        'હાજરી પાક્કી, બસ થોડું વધારે તૈયાર થઈને આવીશ',
      ],
      'opener': [
        'એક સવાલ: વીકેન્ડ પર ફરવું ગમે કે ઘરે આરામ?',
        'આ ફોટો પાછળની મજેદાર સ્ટોરી શું છે?',
        'ચા કે કોફી? સાચો જવાબ આપવો જરૂરી છે!',
      ],
    },
    'hindi': {
      'funny': [
        'खाना है तो पक्का आ रहा हूँ, अपनी प्राथमिकता साफ है 😄',
        'मेरा बिस्तर मुझे छोड़ने को तैयार नहीं, पर सोचते हैं',
        'बस चप्पल पहन रहा हूँ, आ गया समझो',
      ],
      'friendly': [
        'हाँ बिल्कुल! कितने बजे निकल रहे हो?',
        'पक्का आ रहा हूँ, कुछ लाना हो तो बताना',
        'बस काम निपटाकर अभी बताता हूँ!',
      ],
      'flirty': [
        'तुम रहोगी तो ज़रूर आऊँगा 😉',
        'पहले बताओ, मेरे लिए जगह रखी है ना?',
        'तुमने पूछा है तो मना कैसे करूँ',
      ],
      'rizz': [
        'इतनी अच्छी वाइब के बाद कॉफ़ी तो बनती है ✨',
        'तुम्हें टेक्स्ट करने का बस बहाना ढूँढ रहा था',
        'अगर प्लेलिस्ट अच्छी निकली तो अगली ट्रीट मेरी तरफ से',
      ],
      'savage': [
        'जितनी देर में रिप्लाई आया उतनी देर में मौसम बदल गया 👀',
        'बस आपकी ही एनर्जी मैच कर रहा हूँ',
        'कीबोर्ड में और भी शब्द होते हैं, कभी इस्तेमाल कीजिए',
      ],
      'unbothered': [
        'कोई बात नहीं, जब फ़्री हों तब बताइएगा।',
        'सब ठीक है, आराम से अपना काम पूरा कर लें।',
        'चिल है, समय मिले तो बात करते हैं।',
      ],
      'confident': [
        'आ रहा हूँ, लोकेशन भेज दो।',
        'पक्का, तय समय पर मिलते हैं।',
        'मेरी तरफ से डन समझो।',
      ],
      'professional': [
        'जानकारी के लिए धन्यवाद, मैं शाम तक कन्फर्म कर दूँगा।',
        'हाँ, यह समय ठीक है। कृपया एजेंडा साझा करें।',
        'नोट कर लिया है, मैं अपडेट के साथ जुड़ जाऊँगा।',
      ],
      'polite': [
        'पूछने के लिए धन्यवाद! पूरी कोशिश करूँगा आने की।',
        'बहुत अच्छा लगा, एक बार देखकर जल्दी बताता हूँ।',
        'ज़्यादातर हाँ है, बस एक काम निपटा लूँ?',
      ],
      'supportive': [
        'परेशान मत हो, बात करनी हो तो मैं यहीं हूँ।',
        'सब कुछ आज ही सुलझाना ज़रूरी नहीं, तुम अच्छा कर रहे हो।',
        'हम मिलकर सब संभाल लेंगे, बेफिक्र रहो।',
      ],
      'witty': [
        'कैलेंडर से पूछा, उसने पूरा सुने बिना ही हाँ बोल दिया',
        'न्योता है या चुनौती? दोनों के लिए हाँ है',
        'हाज़िरी पक्की, बस थोड़ा ज्यादा तैयार होकर आऊँगा',
      ],
      'opener': [
        'एक ज़रूरी सवाल: चाय या कॉफ़ी? सही जवाब देना!',
        'इस फ़ोटो के पीछे की असली कहानी क्या है?',
        'वीकेंड पर घूमना पसंद है या घर पर आराम?',
      ],
    },
    'hinglish': {
      'funny': [
        'Bhai khana hai toh pakka aa raha hoon 😄',
        'Mera bed mujhe jaane nahi de raha yaar, dekhte hain',
        'Bas chappal pehen raha hoon, aa gaya samjho',
      ],
      'friendly': [
        'Haan bilkul! Kitne baje nikal rahe ho?',
        'Scene set hai, kuch laana hai toh bata do!',
        'Done hai, time aur location bhej do!',
      ],
      'flirty': [
        'Aapne bulaya aur hum na aaye, aisa ho sakta hai kya? 😉',
        'Sirf tab jab saari attention mujhe milegi',
        'Itna sweet message karoge toh mana kaise karun',
      ],
      'rizz': [
        'Subah subah itna distract karne ka fine lagega ✨',
        'Coffee meri taraf se agar playlist achhi nikli toh',
        'Bas tumhe text karne ka bahana dhoondh raha tha',
      ],
      'savage': [
        'Seen pe chhodna hi mera jawab tha, par theek hai',
        'Energy match kar raha hoon bas 👀',
        'Keyboard mein aur bhi letters hain, kabhi try karna',
      ],
      'unbothered': [
        'Chill scene hai, jab free ho bata dena.',
        'No worries yaar, apna kaam nipta le.',
        'Sab badhiya, baad mein baat karte hain.',
      ],
      'confident': [
        'Aa raha hoon, location bhej de.',
        'Pakka, time pe milte hain.',
        'Already plan mein hai boss.',
      ],
      'professional': [
        'Update ke liye thanks, EOD tak confirm karta hoon.',
        'Haan works for me, agenda share kar dena.',
        'Noted, latest numbers ke saath join karunga.',
      ],
      'polite': [
        'Puchne ke liye thanks! Try karunga zaroor aane ka.',
        'Accha laga, ek baar schedule check karke batata hoon.',
        'Aana chahta hoon, bas ek chhota kaam nipta loon?',
      ],
      'supportive': [
        'Tension mat le, baat karni ho toh main hoon.',
        'Sab aaj hi solve karna zaroori nahi yaar.',
        'Tu try kar raha hai, wahi sabse badi baat hai.',
      ],
      'witty': [
        'Calendar se pucha, bina sune haan bol diya',
        'Invite hai ya challenge? Dono mein haan',
        'RSVP done, bas thoda overdressed aaunga',
      ],
      'opener': [
        'Quick sawal: chai ya coffee? Galat jawab pe block!',
        'Iss photo ka backstory sunna padega boss',
        'Weekend pe adventure mode on ya lazy mode?',
      ],
    },
  };

  static ReplyResponse getFallbackReplies(
    ReplyRequest request,
    int remainingCredits,
  ) {
    final tone = request.tone.toLowerCase().trim();
    final lang = request.language.toLowerCase().trim();

    List<String> pool;
    final langKey = lang.contains('gujarat')
        ? 'gujarati'
        : lang.contains('hinglish')
            ? 'hinglish'
            : lang.contains('hindi')
                ? 'hindi'
                : null;

    if (langKey != null && _localizedReplies[langKey] != null) {
      final map = _localizedReplies[langKey]!;
      pool = map[tone] ??
          map.entries
              .firstWhere(
                (e) => tone.contains(e.key) || e.key.contains(tone),
                orElse: () => MapEntry('friendly', map['friendly']!),
              )
              .value;
    } else {
      // English / International
      if (tone.contains('fun')) {
        pool = [
          "Depends, are we talking 'paint the town red' or 'stare blankly at a screen with pizza'?",
          "I'd love to, but my couch and I are in a very committed relationship right now.",
          "Give me 10 minutes to overthink this and I'll confirm."
        ];
      } else if (tone.contains('flirt')) {
        pool = [
          "Only if you promise to make it worth my while 😉",
          "I was hoping you'd ask. What did you have in mind?",
          "Depends, are you saving me the seat next to you?"
        ];
      } else if (tone.contains('rizz')) {
        pool = [
          "You owe me a coffee for distracting me all morning ✨",
          "If you're looking for signs from the universe, this text is one.",
          "Say less — name the place and I'll match your energy."
        ];
      } else if (tone.contains('savage') || tone.contains('unbothered')) {
        pool = tone.contains('unbothered')
            ? [
                "All good, hit me up whenever you're free.",
                "Zero worries, take your time.",
                "Sounds like a plan, keep me posted."
              ]
            : [
                "Left on read was my subtle answer, but here we are.",
                "I'd reply faster, but I was matching your energy.",
                "Did your keyboard run out of letters or just effort?"
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
    final lang = request.language.toLowerCase().trim();
    final vibeTag = '#${request.tone.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';

    if (lang.contains('gujarat')) {
      return CaptionResponse(
        captions: [
          'પ્લાન કંઈક બીજો હતો, થયું કંઈક બીજું — અને એ જ બેસ્ટ હતું ($topic).',
          'નાની પળો, મોટી યાદો. આ દિવસ સાચવી રાખવા જેવો છે ✨',
          'શબ્દો ઓછા અને લાગણી વધારે — ${request.tone} મૂડ.',
        ],
        hooks: [
          'બસ એક નાનો ફેરફાર કર્યો અને આખો મૂડ બદલાઈ ગયો...',
          'આ ભાગ કોઈ તમને પહેલેથી નથી કહેતું!',
        ],
        callToActions: [
          'તમારો આમાં ફેવરિટ હિસ્સો કયો?',
          'એ મિત્રને ટેગ કરો જેને આ જોવું ગમશે!',
        ],
        hashtags: ['#GujaratiVibes', '#RealMoments', '#DailyLife', vibeTag],
        creditsRemaining: remainingCredits,
      );
    }

    if (lang.contains('hinglish')) {
      return CaptionResponse(
        captions: [
          'Plan kuch aur tha, ho kuch aur gaya — aur honestly better hi nikla ($topic).',
          'Chhoti si khushi, bada sukoon. Ye din yaad rakhna hai ✨',
          'Kam shabd, full ${request.tone} vibe.',
        ],
        hooks: [
          'Bas ek chhoti si cheez badli aur poora hafta alag laga...',
          'Ye wala part koi nahi batata!',
        ],
        callToActions: [
          'Tum hote toh kya karte? Comment mein batao!',
          'Us dost ko bhejo jise aaj ye sunna chahiye.',
        ],
        hashtags: ['#DesiVibes', '#RealMoments', '#DailyLife', vibeTag],
        creditsRemaining: remainingCredits,
      );
    }

    if (lang.contains('hindi')) {
      return CaptionResponse(
        captions: [
          'योजना कुछ और थी, हुआ कुछ और — और सच कहूँ तो यही सबसे अच्छा रहा ($topic)।',
          'छोटी-सी खुशी, बड़ा सुकून। यह पल संजोकर रखने लायक है ✨',
          'कम शब्द, ज़्यादा अहसास — ${request.tone} अंदाज़।',
        ],
        hooks: [
          'बस एक छोटी आदत बदली और पूरा दिन अलग लगा...',
          'यह बात अक्सर कोई पहले नहीं बताता!',
        ],
        callToActions: [
          'आपका इस पर क्या ख़याल है? कमेंट में बताएं!',
          'उस दोस्त को भेजें जिसे आज यह पसंद आए।',
        ],
        hashtags: ['#HindiQuotes', '#RealMoments', '#DailyLife', vibeTag],
        creditsRemaining: remainingCredits,
      );
    }

    return CaptionResponse(
      captions: [
        "Not the most productive morning, but definitely the most honest one. $topic",
        "Saving this one so future me remembers how good today felt.",
        "Current mood (${request.tone}): less overthinking, more real moments.",
      ],
      hooks: [
        "The one thing nobody warned me about...",
        "I changed one tiny routine and it made all the difference.",
      ],
      callToActions: [
        "What would you have done here?",
        "Send this to someone who needs this today.",
      ],
      hashtags: [
        "#DailyLife",
        "#SmallWins",
        "#RealMoments",
        vibeTag,
        "#CreatorLife",
      ],
      creditsRemaining: remainingCredits,
    );
  }

  static BioResponse getFallbackBios(
    BioRequest request,
    int remainingCredits,
  ) {
    final interests = request.interests.trim();
    final safeTopic = interests.isEmpty ? 'creative living' : interests;
    final rawUnderscore = safeTopic
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    final rawCompact =
        safeTopic.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final handleSlug = rawUnderscore.isEmpty ? 'vibe' : rawUnderscore;
    final compactSlug = rawCompact.isEmpty ? 'creator' : rawCompact;
    final vibeSlug =
        request.vibe.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final platformSlug =
        request.platform.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final lang = request.language.toLowerCase().trim();

    List<String> bios;
    if (lang.contains('gujarat')) {
      bios = [
        '$safeTopic • ${request.vibe} અંદાજ અને દરરોજ કંઈક નવું ✨',
        'સપનાં મોટાં, વાતો ઓછી અને ${request.platform} પર મસ્ત વાઇબ્સ.',
        'થોડી કોફી, ઘણી ક્રિએટિવિટી — $safeTopic મારી ઓળખ.',
      ];
    } else if (lang.contains('hinglish')) {
      bios = [
        '$safeTopic • ${request.vibe} mindset & good energy only ✨',
        'Bade sapne, simple life, aur ${request.platform} par daily creativity.',
        'Part-time overthinker, full-time $safeTopic enthusiast.',
      ];
    } else if (lang.contains('hindi')) {
      bios = [
        '$safeTopic • ${request.vibe} सोच और सकारात्मक ऊर्जा ✨',
        'बड़े सपने, सरल अंदाज़ और ${request.platform} पर हर दिन कुछ नया।',
        'कम शब्द, गहरा असर — $safeTopic के साथ सफ़र।',
      ];
    } else {
      bios = [
        "$safeTopic • chasing golden hour light and overthinking playlists.",
        "Part-time $safeTopic nerd, full-time ${request.vibe.toLowerCase()} curator.",
        "Building things that matter, living simply, and finding good coffee.",
      ];
    }

    return BioResponse(
      bios: bios,
      usernames: [
        "@${handleSlug}_daily",
        "@the_${vibeSlug.isEmpty ? 'modern' : vibeSlug}_cut",
        "@not_just_$compactSlug",
        "@minimal_${platformSlug.isEmpty ? 'bio' : platformSlug}",
        "@curated_${vibeSlug.isEmpty ? 'aesthetic' : vibeSlug}",
      ],
      creditsRemaining: remainingCredits,
    );
  }

  static VibeCheckResponse getFallbackVibeCheck(
    VibeCheckRequest request,
    int remainingCredits,
  ) {
    final lang = request.language.toLowerCase().trim();
    final mode = request.mode.toLowerCase().trim();

    if (lang.contains('gujarat')) {
      return VibeCheckResponse(
        score: mode == 'roast' ? 54 : 84,
        title: mode == 'flags' ? '🚩 સિગ્નલ ચેક' : 'સ્પષ્ટ અને કોન્ફિડન્ટ',
        verdict:
            'આ મેસેજમાં ઇરાદો સ્પષ્ટ છે, પરંતુ વધારે ઓવરથિંકિંગ ટાળીને ટૂંકો અને કુલ અંદાજ રાખશો તો વધુ અસરકારક લાગશે.',
        tags: ['#Direct', '#CalmVibe', '#Natural'],
        rewrites: [
          'બધું બરાબર છે ને? આ અઠવાડિયે ફ્રી હોવ તો કોફી માટે મળીએ.',
          'તમારો સમય લો, ફ્રી થાઓ ત્યારે જણાવજો.',
          'સરસ! મને કહેજો કે કયો સમય ફાવશે.',
        ],
        creditsRemaining: remainingCredits,
      );
    }

    if (lang.contains('hinglish')) {
      return VibeCheckResponse(
        score: mode == 'roast' ? 54 : 84,
        title: mode == 'flags' ? '🚩 Signal Check' : 'Clear & Confident',
        verdict:
            'Intent sahi hai, bas thoda overthinking kam karke short aur relaxed rakhoge toh reply ka chance kaafi badh jayega.',
        tags: ['#Direct', '#LowPressure', '#Natural'],
        rewrites: [
          'Hey, iss week free ho toh coffee ke liye milte hain?',
          'Koi rush nahi, jab free ho tab bata dena!',
          'Scene sorted rakhte hain — batao kab free ho.',
        ],
        creditsRemaining: remainingCredits,
      );
    }

    if (lang.contains('hindi')) {
      return VibeCheckResponse(
        score: mode == 'roast' ? 54 : 84,
        title: mode == 'flags' ? '🚩 संकेत जांच' : 'स्पष्ट और आत्मविश्वासी',
        verdict:
            'मैसेज का भाव अच्छा है, लेकिन इसे थोड़ा छोटा और सहज रखने से आपका आत्मविश्वास और बेहतर दिखेगा।',
        tags: ['#स्पष्ट', '#सहज', '#संतुलित'],
        rewrites: [
          'नमस्ते, इस सप्ताह समय मिले तो कॉफ़ी पर मिलते हैं?',
          'कोई जल्दी नहीं है, जब फ़्री हों तब बताइएगा।',
          'ठीक है, जब आपका शेड्यूल बने तब बात करते हैं।',
        ],
        creditsRemaining: remainingCredits,
      );
    }

    return VibeCheckResponse(
      score: mode == 'roast' ? 52 : 84,
      title: mode == 'flags' ? '🚩 Signal Check' : 'Clear & Confident',
      verdict:
          "Solid baseline energy with direct intent. Trimming unnecessary hesitation makes this land with effortless main-character confidence.",
      tags: ["#Direct", "#LowPressure", "#Natural"],
      rewrites: [
        "Hey, what does your schedule look like for coffee this Thursday?",
        "Free this week or should we lock in a day?",
        "Let's catch up soon. Let me know when you have a free evening.",
      ],
      creditsRemaining: remainingCredits,
    );
  }
}
