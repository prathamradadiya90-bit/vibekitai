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
  },
};

function asLang(language: string): Lang {
  return (['English', 'Hindi', 'Hinglish', 'Gujarati'] as const).includes(language as Lang) ? (language as Lang) : 'English';
}

export function mockReplies(p: { tone: string; language: string; count?: number }): string[] {
  const byTone = REPLIES[asLang(p.language)];
  const list: string[] = byTone[p.tone] ?? byTone.Friendly ?? [];
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

export function mockBios(p: { interests: string; vibe: string; includeUsernames: boolean }) {
  const words = (p.interests.toLowerCase().match(/[a-z]{3,12}/g) ?? ['coffee', 'music']).slice(0, 3);
  const [a = 'coffee', b = 'music', c = 'late nights'] = words;
  const cap = (w: string) => w.charAt(0).toUpperCase() + w.slice(1);
  return {
    bios: [
      `${cap(a)} • ${cap(b)} • ${cap(c)}\nfiguring it out one post at a time`,
      `Part-time ${a} nerd, full-time ${b} enthusiast.`,
      `I talk about ${a} way too much. DMs open if you do too.`,
    ],
    usernames: p.includeUsernames ? [`@${a}.daily`, `@${a}_and_${b}`.slice(0, 19), `@not.just.${a}`, `@${b}withme`, `@the${a}diary`] : [],
  };
}

export function mockVibeCheck(p: { text: string; mode: string; language: string }) {
  const mode = p.mode || 'roast';
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
  }

  return { score, title, verdict, tags, rewrites };
}
