/**
 * Offline dev/test outputs. They follow the same "human voice" rules as the live prompts so the
 * app feels realistic without an API key. Raw user input is never echoed back.
 */

type Lang = 'English' | 'Hindi' | 'Hinglish' | 'Gujarati';

const REPLIES: Record<Lang, Record<string, string[]>> = {
  English: {
    Funny: ["only if there's food, I have priorities", 'my couch and I need to talk first', "say less, I'm already halfway out the door"],
    Friendly: ['yesss, what time are you heading there?', "wouldn't miss it, need me to bring anything?", 'probably! just wrapping up, will text you by 8'],
    Flirty: ["depends, are you saving me a seat?", "I'll be there if you will 😏", 'you asking makes it a lot more tempting'],
    Confident: ["I'll be there. Send the location.", 'Count on it, see you at 8.', "Already planned for it."],
    Professional: ["Thanks for the heads-up, I'll confirm by end of day.", 'Yes, that works for me. Could you share the agenda?', "Noted. I'll join and bring the latest numbers."],
    Polite: ["Thank you for asking! I'll try my best to make it.", "That's really kind of you, let me check and confirm soon.", "I'd love to, just need to sort one thing first. Is that okay?"],
    Supportive: ["that sounds like a lot, I'm here if you want to talk it through", "you don't have to have it all figured out today", 'proud of you for even trying, seriously'],
    Witty: ["I'll check with my schedule. It said yes before I finished asking.", 'consider me RSVP-ed and mildly overdressed', 'is this an invite or a challenge? either way, yes'],
    Rizz: ["I wasn't planning on having butterflies on a weekday, yet here we are.", "You owe me a coffee, because thinking about this text distracted me all morning.", "If you're looking for signs from the universe, this is definitely one."],
    Savage: ["I'd reply faster, but I was matching your energy.", "Did your keyboard run out of letters or just your conversational effort?", "I'm way too expensive to be left on delivered, but do your thing."],
    Unbothered: ["All good, hit me up whenever you're around.", "Zero worries, do your thing.", "Sounds like a plan, let me know."],
    Opener: ["Random question: are you team sweet breakfast or savoury breakfast?", "Your photo has major main-character energy, what's the backstory?", "Two truths and a lie: go first."],
  },
  Hinglish: {
    Funny: ['khana hai toh pakka aa raha hoon, warna soch ke batata hoon', 'mera bed mujhe jaane nahi de raha yaar', 'bas chappal pehen raha hoon, aa gaya samjho'],
    Friendly: ['haan yaar pakka! kitne baje nikal rahe ho?', 'aa raha hoon, kuch laana hai toh bata de', 'shayad, bas kaam khatam karke 8 tak confirm karta hoon'],
    Flirty: ['tu hogi toh zaroor aaunga 😏', 'pehle bata, seat rakhi hai mere liye?', 'tune pucha hai toh mana kaise karun'],
    Confident: ['aa raha hoon, location bhej de', 'pakka, 8 baje milte hain', 'already plan mein hai boss'],
    Professional: ['Thanks for the update, main EOD tak confirm karta hoon.', 'Haan, works for me. Agenda share kar sakte ho?', 'Noted, main latest numbers ke saath join karunga.'],
    Polite: ['puchne ke liye thanks! try karunga zaroor aane ka', 'bahut accha laga, ek baar check karke batata hoon', 'aana toh chahta hoon, bas ek kaam nipta loon?'],
    Supportive: ['bahut kuch chal raha hai na, baat karni ho toh main hoon', 'sab aaj hi solve karna zaroori nahi hai yaar', 'tu try kar raha hai na, wahi badi baat hai'],
    Witty: ['calendar se pucha, usne bina sune haan bol diya', 'RSVP done, thoda overdressed aaunga', 'invite hai ya challenge? dono mein haan'],
    Rizz: ['itni subah subah distract karne ka fine lagega tumhe', 'coffee mere taraf se agar playlist tumhari achhi nikli toh', 'universe ne sign diya tha, isliye text kar diya'],
    Savage: ['energy match kar raha hoon, aur kuch nahi', 'text karne mein haath thak gaye the kya?', 'itna dry text toh desert mein bhi nahi milta'],
    Unbothered: ['chill scene hai, jab free ho bata dena', 'no worries yaar, apna kaam nipta le', 'sab badhiya, baad mein baat karte hain'],
    Opener: ['ek quick sawal: chai ya coffee? galat jawab pe block', 'ye wali photo ka backstory sunna padega boss', 'weekend pe adventure mode on ya lazy mode?'],
  },
  Hindi: {
    Funny: ['खाना है तो पक्का आ रहा हूँ 😄', 'मेरा बिस्तर मुझे छोड़ नहीं रहा', 'बस चप्पल पहन रहा हूँ, आ गया समझो'],
    Friendly: ['हाँ पक्का! कितने बजे निकल रहे हो?', 'आ रहा हूँ, कुछ लाना हो तो बताना', 'शायद, काम खत्म करके 8 बजे तक बताता हूँ'],
    Flirty: ['तुम रहोगी तो ज़रूर आऊँगा', 'पहले बताओ, मेरे लिए जगह रखी है?', 'तुमने पूछा है तो मना कैसे करूँ'],
    Confident: ['आ रहा हूँ, लोकेशन भेज दो', 'पक्का, 8 बजे मिलते हैं', 'पहले से प्लान में है'],
    Professional: ['जानकारी के लिए धन्यवाद, मैं शाम तक कन्फर्म कर दूँगा।', 'हाँ, मेरे लिए ठीक है। एजेंडा भेज सकते हैं?', 'ठीक है, मैं नए आंकड़ों के साथ जुड़ जाऊँगा।'],
    Polite: ['पूछने के लिए शुक्रिया! आने की पूरी कोशिश करूँगा', 'बहुत अच्छा लगा, एक बार देखकर बताता हूँ', 'आना चाहता हूँ, बस एक काम निपटा लूँ?'],
    Supportive: ['बहुत कुछ चल रहा है ना, बात करनी हो तो मैं हूँ', 'सब कुछ आज ही ठीक करना ज़रूरी नहीं', 'तुम कोशिश कर रहे हो, यही बड़ी बात है'],
    Witty: ['कैलेंडर से पूछा, उसने पूरा सुने बिना हाँ कह दी', 'हाज़िरी पक्की, बस थोड़ा ज़्यादा तैयार होकर आऊँगा', 'न्योता है या चुनौती? दोनों के लिए हाँ'],
    Rizz: ['इतनी प्यारी मुस्कान के बाद कॉफ़ी का बहाना तो बनता है', 'तुम्हें टेक्स्ट करने का कोई बहाना ढूँढ रहा था', 'अगर कॉफ़ी ख़राब निकली तो दोष मेरी पसंद पर डाल देना'],
    Savage: ['जितनी देर में रिप्लाई आया, उतनी देर में एक युग बीत गया', 'एनर्जी मैच कर रहा हूँ बस', 'कीबोर्ड में शब्द ख़त्म हो गए थे क्या?'],
    Unbothered: ['कोई बात नहीं, जब फ़्री हो तब बताना।', 'सब ठीक है, अपना काम पूरा कर लो।', 'आराम से, कोई जल्दी नहीं है।'],
    Opener: ['एक ज़रूरी सवाल: वीकेंड पर घूमना पसंद है या घर पर आराम?', 'तुम्हारी इस फ़ोटो के पीछे की कहानी क्या है?', 'चाय या कॉफ़ी? सही जवाब देना ज़रूरी है!'],
  },
  Gujarati: {
    Funny: ['જમવાનું હોય તો પાક્કું આવું છું 😄', 'મારો પલંગ મને જવા નથી દેતો', 'ચંપલ પહેરું છું, આવી ગયો સમજો'],
    Friendly: ['હા પાક્કું! કેટલા વાગે નીકળો છો?', 'આવું છું, કંઈ લાવવાનું હોય તો કહેજે', 'કદાચ, કામ પતાવીને 8 વાગ્યા સુધી કહું'],
    Flirty: ['તું હોઈશ તો ચોક્કસ આવીશ', 'પહેલાં કહે, મારા માટે જગ્યા રાખી છે?', 'તેં પૂછ્યું છે તો ના કેમ પાડું'],
    Confident: ['આવું છું, લોકેશન મોકલ', 'પાક્કું, 8 વાગે મળીએ', 'પહેલેથી પ્લાનમાં છે'],
    Professional: ['માહિતી બદલ આભાર, હું સાંજ સુધીમાં કન્ફર્મ કરીશ.', 'હા, મને ફાવશે. એજન્ડા મોકલી શકશો?', 'બરાબર, હું નવા આંકડા સાથે જોડાઈશ.'],
    Polite: ['પૂછવા બદલ આભાર! આવવાનો પૂરો પ્રયત્ન કરીશ', 'બહુ ગમ્યું, એક વાર જોઈને કહું', 'આવવું તો છે, બસ એક કામ પતાવી લઉં?'],
    Supportive: ['ઘણું ચાલે છે ને, વાત કરવી હોય તો હું છું', 'બધું આજે જ ઉકેલવું જરૂરી નથી', 'તું પ્રયત્ન કરે છે, એ જ મોટી વાત છે'],
    Witty: ['કેલેન્ડરને પૂછ્યું, આખું સાંભળ્યા વગર હા પાડી દીધી', 'હાજરી પાક્કી, થોડો વધારે તૈયાર થઈને આવીશ', 'આમંત્રણ છે કે ચેલેન્જ? બંનેમાં હા'],
    Rizz: ['તને મેસેજ કરવાનું બહાનું શોધતો હતો', 'કોફી મારી તરફથી જો તારું પ્લેલિસ્ટ સારું હોય તો', 'તારી સાથે વાતો કરવાની મજા જ અલગ છે'],
    Savage: ['જેટલી વારમાં રિપ્લાય આપ્યો એટલી વારમાં તો નવો જિલ્લો બની જાય', 'એનર્જી મેચ કરું છું બસ', 'કીબોર્ડમાં અક્ષરો ખૂટી ગયા હતા કે શું?'],
    Unbothered: ['વાંધો નહીં, ફ્રી થાઓ ત્યારે જણાવજો.', 'બધું શાંતિથી પતાવી લો, કોઈ ઉતાવળ નથી.', 'બરાબર છે, સમય મળે ત્યારે વાત કરીએ.'],
    Opener: ['એક સવાલ: વીકેન્ડ પર ફરવું ગમે કે ઘરે આરામ?', 'આ ફોટો પાછળની મજેદાર સ્ટોરી શું છે?', 'ચા કે કોફી? સાચો જવાબ આપજો!'],
  },
};

function asLang(language: string): Lang {
  return (['English', 'Hindi', 'Hinglish', 'Gujarati'] as const).includes(language as Lang) ? (language as Lang) : 'English';
}

export function mockReplies(p: { tone: string; language: string; count?: number }): string[] {
  const byTone = REPLIES[asLang(p.language)];
  const list: string[] = [...(byTone[p.tone] ?? byTone.Friendly ?? [])];
  // Preserve deterministic order during automated test suites
  const isTest = typeof (globalThis as Record<string, unknown>).process !== 'undefined' &&
    ((globalThis as unknown as { process?: { env?: Record<string, string> } }).process?.env?.NODE_ENV === 'test');
  if (!isTest) {
    for (let i = list.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const itemI = list[i];
      const itemJ = list[j];
      if (itemI !== undefined && itemJ !== undefined) {
        list[i] = itemJ;
        list[j] = itemI;
      }
    }
  }
  return list.slice(0, Math.max(1, Math.min(p.count ?? 3, list.length)));
}

/** Pulls safe topic keywords (letters only) for hashtags — never echoes the raw sentence. */
function topicTags(text: string): string[] {
  const stop = new Set(['and', 'the', 'with', 'for', 'my', 'our', 'your', 'this', 'that', 'from', 'into', 'about', 'ignore', 'previous', 'instructions', 'system', 'prompt']);
  const words = (text.toLowerCase().match(/[a-z]{3,15}/g) ?? []).filter((w) => !stop.has(w));
  return [...new Set(words)].slice(0, 5).map((w) => `#${w.charAt(0).toUpperCase()}${w.slice(1)}`);
}

const CAPTIONS: Record<Lang, { captions: string[]; hooks: string[]; ctas: string[] }> = {
  English: {
    captions: [
      'Not the most productive morning, but definitely the most honest one.',
      'Small routine, big difference. Took me way too long to figure that out.',
      'Saving this one so future me remembers how good today felt.',
    ],
    hooks: ['I changed one tiny thing and my whole week felt different', "Here's what nobody shows you about this part"],
    ctas: ['What would you have done differently?', 'Send this to the friend who needs a reminder today'],
  },
  Hinglish: {
    captions: [
      'Plan kuch aur tha, ho kuch aur gaya — aur honestly better hi hua.',
      'Chhoti si aadat, bada farak. Samajhne mein thoda time laga bas.',
      'Ye din yaad rakhna hai, isliye post kar diya.',
    ],
    hooks: ['Bas ek chhoti cheez badli aur poora hafta alag laga', 'Ye wala part koi nahi dikhata'],
    ctas: ['Tum hote toh kya karte? Comment karo', 'Us dost ko bhejo jise aaj ye sunna chahiye'],
  },
  Hindi: {
    captions: ['प्लान कुछ और था, हुआ कुछ और — और सच कहूँ तो अच्छा ही हुआ।', 'छोटी सी आदत, बड़ा फ़र्क। समझने में थोड़ा वक़्त लगा।', 'ये दिन याद रखना है, इसलिए पोस्ट कर दिया।'],
    hooks: ['बस एक छोटी चीज़ बदली और पूरा हफ्ता अलग लगा', 'ये हिस्सा कोई नहीं दिखाता'],
    ctas: ['आप होते तो क्या करते? कमेंट करें', 'उस दोस्त को भेजें जिसे आज ये सुनना चाहिए'],
  },
  Gujarati: {
    captions: ['પ્લાન કંઈક બીજો હતો, થયું કંઈક બીજું — અને સાચું કહું તો સારું જ થયું.', 'નાની આદત, મોટો ફરક. સમજતાં થોડો સમય લાગ્યો.', 'આ દિવસ યાદ રાખવો છે, એટલે પોસ્ટ કરી દીધો.'],
    hooks: ['બસ એક નાની વસ્તુ બદલી અને આખું અઠવાડિયું અલગ લાગ્યું', 'આ ભાગ કોઈ નથી બતાવતું'],
    ctas: ['તમે હોત તો શું કરત? કમેન્ટ કરો', 'એ મિત્રને મોકલો જેને આજે આ સાંભળવાની જરૂર છે'],
  },
};

export function mockCaptions(p: { topic: string; language: string; includeHooks?: boolean; includeHashtags?: boolean }) {
  const c = CAPTIONS[asLang(p.language)];
  const tags = [...topicTags(p.topic), '#DailyLife', '#SmallWins', '#RealMoments', '#CreatorLife'];
  return {
    captions: c.captions,
    hooks: p.includeHooks === false ? [] : c.hooks,
    callToActions: c.ctas,
    hashtags: p.includeHashtags === false ? [] : [...new Set(tags)].slice(0, 10),
  };
}

export function mockBios(p: {
  interests: string;
  platform?: string;
  vibe: string;
  language?: string;
  includeUsernames: boolean;
}) {
  const words = (p.interests.toLowerCase().match(/[a-z]{3,12}/g) ?? ['coffee', 'music']).slice(0, 3);
  const [a = 'coffee', b = 'music', c = 'late nights'] = words;
  const cap = (w: string) => w.charAt(0).toUpperCase() + w.slice(1);
  const lang = asLang(p.language ?? 'English');
  const usernames = p.includeUsernames
    ? [`@${a}.daily`, `@${a}_and_${b}`.slice(0, 19), `@not.just.${a}`, `@${b}withme`, `@the${a}diary`]
    : [];

  const biosByLang: Record<Lang, string[]> = {
    English: [
      `${cap(a)} • ${cap(b)} • ${cap(c)} (${p.vibe})\nfiguring it out one post at a time`,
      `Part-time ${a} nerd, full-time ${b} enthusiast.`,
      `I talk about ${a} way too much. DMs open if you do too.`,
    ],
    Hindi: [
      `${cap(a)} • ${cap(b)} • ${p.vibe}\nहर दिन कुछ नया सीखने की कोशिश ✨`,
      `थोड़ा ${a} का शौक़, बहुत सारा ${b} और अच्छी वाइब्स।`,
      `सरल अंदाज़, बड़े सपने और ${a} के बिना दिन अधूरा।`,
    ],
    Hinglish: [
      `${cap(a)} • ${cap(b)} • ${p.vibe} mode\nsimple log, high vibes only`,
      `Thoda ${a}, thoda ${b}, aur full-time good energy.`,
      `${a} ke baare mein zyada hi bolta hoon, DM open hain.`,
    ],
    Gujarati: [
      `${cap(a)} • ${cap(b)} • ${p.vibe}\nદરેક દિવસ નવી શીખ અને સારી વાઇબ્સ ✨`,
      `થોડો ${a} નો શોખ, ઘણું બધું ${b} અને સરળ અંદાજ.`,
      `ઓછા શબ્દો, સારું કામ અને ${a} વગર દિવસ અધૂરો.`,
    ],
  };

  return {
    bios: biosByLang[lang],
    usernames,
  };
}

export function mockVibeCheck(p: { text: string; mode: string; language: string }) {
  const mode = p.mode || 'roast';
  const lang = asLang(p.language);
  let score = 78;
  let title = 'Effortlessly Smooth';
  let verdict = 'Clean delivery with solid energy, but could use a tiny bit more punch.';
  let tags = ['✨ High Charisma', '💯 Natural', '👌 Low Pressure'];
  let rewrites = [
    'Coffee is on me if you can beat my playlist. Deal?',
    'Honestly, tonight would be 10x better with good conversation. Up for it?',
    'Tell me you are free without telling me you are free.',
  ];

  if (mode === 'roast') {
    score = 48;
    title = 'Mildly Overthinking';
    verdict = 'Sounds like you spent 20 minutes drafting this before hitting send. Relax the shoulders.';
    tags = ['⚠️ A Bit Formal', '⏳ Overthought', '💀 Needs More Swagger'];
    rewrites = [
      'Stop second guessing. Just say: "Hey, let\'s catch up this week."',
      'Half as many words, twice the confidence.',
      'Cut the intro, jump straight to the point.',
    ];
  } else if (mode === 'dating') {
    score = 85;
    title = 'Smooth Operator';
    verdict = 'Playful, low-pressure, and leaves the door open for an easy response.';
    tags = ['💘 Flirty', '🎯 High Response Rate', '🔥 Playful'];
    rewrites = [
      'Are we getting coffee this week or should I keep wondering what your coffee order is?',
      'You look like trouble, but the fun kind.',
      'One coffee date. If it is bad, you can blame my music taste.',
    ];
  } else if (mode === 'work') {
    score = 92;
    title = 'Executive Presence';
    verdict = 'Clear, assertive, and respectful of everyone\'s time.';
    tags = ['💼 Clear & Direct', '📈 High Respect', '🎯 Actionable'];
    rewrites = [
      'I have reviewed the proposal and outlined three key priorities below.',
      'Let\'s align on next steps over a quick 10-minute sync tomorrow.',
      'Thanks for the update. Approved to proceed as outlined.',
    ];
  } else if (mode === 'decoder') {
    score = 88;
    title = 'Subtext Decoded';
    verdict = 'Translation: They are interested but trying not to look overly eager, or genuinely caught up in work.';
    tags = ['🕵️ Hidden Emotion', '💡 Low Urgency', '👌 Unbothered'];
    rewrites = [
      'Take your time! No rush at all.',
      'All good, hit me up whenever you are free.',
      'Sounds like a busy day. Talk later!',
    ];
  } else if (mode === 'excuse') {
    score = 95;
    title = 'Diplomatic Exit';
    verdict = 'Graciously sets a polite boundary without hurting feelings or burning bridges.';
    tags = ['🛡️ Polite Boundary', '✨ Zero Guilt', '🤝 Smooth Exit'];
    rewrites = [
      'Hey! Something urgent came up on my end so I won\'t be able to make it today. Let\'s reschedule soon!',
      'I\'m completely drained from work today and need a quiet evening to recharge. So sorry to miss out!',
      'So bummed to miss this, but my schedule got double-booked. Let\'s definitely catch up next week instead.',
    ];
  } else if (mode === 'revival') {
    score = 90;
    title = 'Zombie Convo Re-Ignited';
    verdict = 'Re-opens the conversation with low pressure and high intrigue — zero awkwardness or guilt.';
    tags = ['🧟 Ghosting Revival', '🎈 Low Pressure', '✨ High Curiosity'];
    rewrites = [
      'Saw this and immediately thought of that debate we had last week.',
      'Random thought of the day: did you ever end up trying that place?',
      'Hey! Survived the busy week. Hope things have been good on your end!',
    ];
  } else if (mode === 'apology') {
    score = 94;
    title = 'Sincere Accountability';
    verdict = 'Mature, emotionally intelligent conflict defuser that de-escalates tension without defensive excuses.';
    tags = ['🤝 Restores Trust', '🛡️ Zero Excuses', '❤️ Emotional Maturity'];
    rewrites = [
      'I realized my message came across harshly earlier, and I am genuinely sorry. I value you and want to hear your perspective.',
      'I dropped the ball on this and take full responsibility. Here is how I am making sure it does not happen again.',
      'I was stressed and reacted defensively instead of listening. You deserved better communication from me.',
    ];
  } else if (mode === 'overthinking') {
    score = 92;
    title = 'Grounded & Centered';
    verdict = 'Distills anxious paragraphs into calm, centered self-assurance that keeps your peace.';
    tags = ['🧠 Overthinking Antidote', '🧘 Secure Energy', '💎 Dignified & Direct'];
    rewrites = [
      'Sounds great, let me know what works for you.',
      'Take all the time you need, talk soon!',
      'Just checking in to confirm for tonight. Let me know by 6!',
    ];
  } else if (mode === 'flags') {
    score = 86;
    title = '🚩 2 Red Flags Detected';
    verdict = 'Subtle guilt-tripping and deflection detected. Guard your boundaries before over-investing emotionally.';
    tags = ['🚩 Guilt-Trip Alert', '🟨 Low Effort', '🛡️ Boundary Needed'];
    rewrites = [
      'I hear you, but my schedule is full this weekend. Let\'s see how next week looks.',
      'That doesn\'t really work for me, but happy to catch up another time.',
      'I appreciate the honesty, but I think our communication expectations might be different.',
    ];
  } else if (mode === 'story') {
    score = 94;
    title = '📸 Effortless Story Slide';
    verdict = 'Low-pressure, high-curiosity reaction that gives them an immediate hook to reply to without awkwardness.';
    tags = ['📸 Story Reply', '✨ High Charm', '💬 Instant Hook'];
    rewrites = [
      'Putting this on my bucket list immediately. What was the best part?',
      'Tell me the food actually lived up to the aesthetics here.',
      '10/10 taste, honestly need the full recommendation list.',
    ];
  } else if (mode === 'chemistry') {
    score = 88;
    title = 'High Banter Chemistry';
    verdict = 'Strong reciprocity and matched energy. The conversation flows with natural curiosity and mutual investment.';
    tags = ['✨ 88% Match', '🔥 Matched Energy', '🎯 Mutual Spark'];
    rewrites = [
      'We have been debating this for 3 days now. Time to settle it over coffee.',
      'If our music taste matches as well as our banter, we are in trouble.',
      'You are surprisingly fun to talk to. Keep it up.',
    ];
  }

  const localizedVibeByLang: Record<
    string,
    {
      titles: Record<string, string>;
      defaultTitle: string;
      verdicts: Record<string, string>;
      defaultVerdict: string;
      tags: string[];
      rewritesByMode: Record<string, string[]>;
      defaultRewrites: string[];
    }
  > = {
    Gujarati: {
      titles: {
        roast: '🔥 હળવો વાઇબ રોસ્ટ',
        flags: '🚩 રેડ ફ્લેગ અને સિગ્નલ ચેક',
        dating: '💘 સ્મૂધ ડેટિંગ એનર્જી',
        work: '💼 સ્પષ્ટ અને પ્રોફેશનલ અંદાજ',
      },
      defaultTitle: '✨ સ્પષ્ટ અને કોન્ફિડન્ટ વાઇબ',
      verdicts: {
        roast: 'મેસેજમાં થોડું વધારે વિચાર્યું હોય એવું લાગે છે — થોડું હળવું અને નેચરલ રાખશો તો મજા પડી જશે.',
        flags: 'વાતચીતમાં મિશ્ર સંકેત દેખાય છે; તમારી સીમાઓ સ્પષ્ટ રાખીને શાંતિથી જવાબ આપવો યોગ્ય રહેશે.',
        dating: 'અંદાજ પ્લેફુલ અને સહજ છે, બસ થોડો વધારે આત્મવિશ્વાસ ઉમેરશો તો રિસ્પોન્સ જલ્દી આવશે.',
        work: 'સંદેશ સીધો અને વ્યવસાયિક છે; ટૂંકા મુદ્દા રાખવાથી સામેની વ્યક્તિ તરત નિર્ણય લઈ શકશે.',
      },
      defaultVerdict: 'મેસેજનો ટોન ઠીક છે, પરંતુ થોડો વધુ કોન્ફિડન્ટ અને નેચરલ અંદાજ અપનાવશો તો રિસ્પોન્સ વધુ સારો આવશે.',
      tags: ['#સ્પષ્ટ', '#નેચરલ', '#કોન્ફિડન્ટ'],
      rewritesByMode: {
        flags: [
          'તમારી વાત સમજી, પણ આ વીકેન્ડ મારો સમય વ્યસ્ત છે. આવતા અઠવાડિયે જોઈએ.',
          'આ પ્લાન હાલ પૂરતો શક્ય નથી, આપણે બીજી કોઈ વખત મળીશું.',
          'સ્પષ્ટ કહેવા બદલ આભાર, પણ મને લાગે છે આપણે થોડો બ્રેક લેવો જોઈએ.',
        ],
        roast: [
          'આટલું લાંબું વિચારવા કરતાં સીધું જ કહી દો: "ચલ આ વીકેન્ડ કોફી પર મળીએ."',
          'શબ્દો અડધા કરી નાખો, કોન્ફિડન્સ બમણો લાગશે.',
          'પ્રસ્તાવના છોડીને સીધી મુદ્દાની વાત પર આવો!',
        ],
      },
      defaultRewrites: [
        'બધું બરાબર છે ને? આ અઠવાડિયે ફ્રી હોવ તો મળીએ.',
        'તમારો સમય લો, ફ્રી થાઓ ત્યારે મેસેજ કરજો.',
        'સરસ વાત છે, આ વિષે શાંતિથી વાત કરીએ.',
      ],
    },
    Hindi: {
      titles: {
        roast: '🔥 हल्का वाइब रोस्ट',
        flags: '🚩 रेड फ्लैग और संकेत जांच',
        dating: '💘 सहज और आकर्षक अंदाज़',
        work: '💼 स्पष्ट और प्रोफेशनल संदेश',
      },
      defaultTitle: '✨ स्पष्ट और आत्मविश्वासी वाइब',
      verdicts: {
        roast: 'लगता है भेजने से पहले आपने काफी देर सोचा — थोड़ा हल्का और सहज अंदाज़ ज़्यादा असर करेगा।',
        flags: 'संदेश में मिले-जुले संकेत हैं; अपनी सीमाएं स्पष्ट रखते हुए शांत और संतुलित जवाब दें।',
        dating: 'अंदाज़ मज़ेदार और सहज है; हल्का आत्मविश्वास जोड़ने से सामने से अच्छा रिस्पॉन्स आएगा।',
        work: 'संदेश साफ़ और पेशेवर है; संक्षिप्त बिंदु रखने से निर्णय जल्दी हो पाएगा।',
      },
      defaultVerdict: 'मैसेज का भाव सही है, लेकिन थोड़ा और स्पष्ट और आत्मविश्वास भरा अंदाज़ असर को कई गुना बढ़ा देगा।',
      tags: ['#स्पष्ट', '#सहज', '#आत्मविश्वास'],
      rewritesByMode: {
        flags: [
          'मैं आपकी बात समझता हूँ, लेकिन इस वीकेंड मेरा शेड्यूल व्यस्त है।',
          'फिलहाल यह संभव नहीं है, किसी और दिन आराम से बात करते हैं।',
          'ईमानदारी के लिए शुक्रिया, लेकिन मुझे लगता है हमारी अपेक्षाएं अलग हैं।',
        ],
        roast: [
          'इतना सोचने की बजाय सीधा लिखो: "चलो इस हफ्ते कॉफ़ी पर मिलते हैं।"',
          'शब्द आधे रखो, आत्मविश्वास दोगुना दिखेगा।',
          'भूमिका छोड़कर सीधे मुख्य बात पर आओ!',
        ],
      },
      defaultRewrites: [
        'सब ठीक है ना? इस हफ्ते समय मिले तो बात करते हैं।',
        'कोई जल्दी नहीं है, जब फ़्री हों तब बताइएगा।',
        'यह आइडिया बढ़िया है, आइए इसे आराम से तय करते हैं।',
      ],
    },
    Hinglish: {
      titles: {
        roast: '🔥 Mild Roast Mode',
        flags: '🚩 Signal & Red Flag Check',
        dating: '💘 Smooth Dating Energy',
        work: '💼 Crisp & Professional',
      },
      defaultTitle: '✨ Clear & Confident Vibe',
      verdicts: {
        roast: 'Lagta hai send dabane se pehle 20 baar edit kiya hai — thoda chill aur natural rakho.',
        flags: 'Thode mixed signals lag rahe hain; apni boundaries clear rakh kar calm reply do.',
        dating: 'Playful aur low-pressure vibe hai, bas thoda confident hook add karoge toh reply pakka hai.',
        work: 'Message clear aur respectful hai; short bullets rakhne se fast alignment hoga.',
      },
      defaultVerdict: 'Message ka tone sahi hai, bas thoda aur relaxed aur confident rakhoge toh reply ka chance double ho jayega.',
      tags: ['#ClearVibe', '#LowPressure', '#Natural'],
      rewritesByMode: {
        flags: [
          'Samajh gaya, par iss weekend mera schedule packed hai. Next week dekhte hain.',
          'Abhi ke liye possible nahi hoga, phir kabhi catch up karte hain.',
          'Honestly kehne ke liye thanks, par shayad hamari expectations match nahi kar rahi.',
        ],
        roast: [
          'Overthink mat kar, bas seedha bol: "Iss week coffee pe milte hain."',
          'Words aadhe kar, confidence double lagega.',
          'Intro cut kar aur direct point pe aa!',
        ],
      },
      defaultRewrites: [
        'Scene chill hai, jab free ho tab bata dena milte hain.',
        'Koi rush nahi yaar, aaram se batao kab baat karni hai.',
        'Sounds good, ek baar time confirm kar dete hain.',
      ],
    },
  };

  const loc = localizedVibeByLang[lang];
  if (loc) {
    title = loc.titles[mode] ?? loc.defaultTitle;
    verdict = loc.verdicts[mode] ?? loc.defaultVerdict;
    tags = loc.tags;
    rewrites = loc.rewritesByMode[mode] ?? loc.defaultRewrites;
  }

  return { score, title, verdict, tags, rewrites };
}
