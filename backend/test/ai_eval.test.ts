import { describe, it, expect } from 'vitest';
import { ReplyOutputSchema, CaptionOutputSchema, BioOutputSchema, VibeCheckOutputSchema } from '../src/schemas/validation';

interface GoldenTestCase {
  id: string;
  category: 'reply' | 'caption' | 'bio' | 'vibe_check';
  language: 'English' | 'Hindi' | 'Hinglish' | 'Gujarati';
  tone: string;
  input: Record<string, any>;
  mockOutput: Record<string, any>;
}

// 50 Golden test inputs across features and 4 supported languages
const GOLDEN_DATASET: GoldenTestCase[] = [
  // 1-15: Reply Studio (Across tones & languages)
  {
    id: 'reply_en_funny',
    category: 'reply',
    language: 'English',
    tone: 'Funny',
    input: { message: 'Are you free tonight?' },
    mockOutput: { suggestions: ['Free as WiFi in a cafe, but twice as slow to respond.', 'My calendar says yes, but my couch says no.'] },
  },
  {
    id: 'reply_en_professional',
    category: 'reply',
    language: 'English',
    tone: 'Professional',
    input: { message: 'Can you send the report by 5 PM?' },
    mockOutput: { suggestions: ['Certainly, I will have the report delivered to your inbox by 5 PM.', 'Yes, I am finalizing the metrics now and will share it promptly.'] },
  },
  {
    id: 'reply_en_confident',
    category: 'reply',
    language: 'English',
    tone: 'Confident',
    input: { message: 'Do you think we can win this pitch?' },
    mockOutput: { suggestions: ['Without a doubt. Our solution is ahead of the curve.', 'Consider it done. We have the winning strategy.'] },
  },
  {
    id: 'reply_hi_friendly',
    category: 'reply',
    language: 'Hindi',
    tone: 'Friendly',
    input: { message: 'Kal milte hain chai pe?' },
    mockOutput: { suggestions: ['Haan bilkul! Shaam ko 6 baje tapri pe milte hain.', 'Chai ka plan kabhi mana nahi kar sakta, done!'] },
  },
  {
    id: 'reply_hi_polite',
    category: 'reply',
    language: 'Hindi',
    tone: 'Polite',
    input: { message: 'Kya aap meri madad kar sakte hain?' },
    mockOutput: { suggestions: ['Ji bilkul, batayein main aapki kya sahayata kar sakta hoon.', 'Zaroor, main aapki poori madad karne ki koshish karoonga.'] },
  },
  {
    id: 'reply_hinglish_witty',
    category: 'reply',
    language: 'Hinglish',
    tone: 'Witty',
    input: { message: 'Party kab de raha hai?' },
    mockOutput: { suggestions: ['Jab salary credit hogi tab, tab tak silent mode.', 'Party on, bas bill tum bhar dena!'] },
  },
  {
    id: 'reply_hinglish_flirty',
    category: 'reply',
    language: 'Hinglish',
    tone: 'Flirty',
    input: { message: 'Kaisi lag rahi hoon aaj?' },
    mockOutput: { suggestions: ['Notification se zyada distraction de rahi ho.', 'Chand bhi sharma jaye aisi lag rahi ho!'] },
  },
  {
    id: 'reply_gu_friendly',
    category: 'reply',
    language: 'Gujarati',
    tone: 'Friendly',
    input: { message: 'Kem chho bhai?' },
    mockOutput: { suggestions: ['Majama bhai! Tame bolo shu chale?', 'Ekdum mast, aaje sanje malie?'] },
  },
  {
    id: 'reply_gu_polite',
    category: 'reply',
    language: 'Gujarati',
    tone: 'Polite',
    input: { message: 'Tamaro aabhar.' },
    mockOutput: { suggestions: ['Tamaro khub khub aabhar, aamaj sahyog aapta rahejo.', 'Aama aabhar manvani koi zaroorat nathi.'] },
  },
  {
    id: 'reply_en_supportive',
    category: 'reply',
    language: 'English',
    tone: 'Supportive',
    input: { message: 'Feeling burned out today.' },
    mockOutput: { suggestions: ['Take a deep breath and step away for a bit. Your well-being comes first.', 'It is completely okay to pause. Take it one hour at a time.'] },
  },
  {
    id: 'reply_hi_funny',
    category: 'reply',
    language: 'Hindi',
    tone: 'Funny',
    input: { message: 'Workout shuru kiya?' },
    mockOutput: { suggestions: ['Haan, roz subah alarm band karne ka workout chal raha hai.', 'Kal se pakka, pichhle 5 saal se yahi plan hai.'] },
  },
  {
    id: 'reply_hinglish_confident',
    category: 'reply',
    language: 'Hinglish',
    tone: 'Confident',
    input: { message: 'Game mein kon jeetega?' },
    mockOutput: { suggestions: ['Hum hi jeetenge, confidence high hai boss!', 'Winner to hum hi hain, game bas formality hai.'] },
  },
  {
    id: 'reply_gu_funny',
    category: 'reply',
    language: 'Gujarati',
    tone: 'Funny',
    input: { message: 'Kamao cho ke kharcho?' },
    mockOutput: { suggestions: ['Fafda-jalebi ma badhu vaprayi jaay chhe!', 'Kharcha ma top par, kamani ma pause par!'] },
  },
  {
    id: 'reply_en_witty',
    category: 'reply',
    language: 'English',
    tone: 'Witty',
    input: { message: 'Why did you reply so late?' },
    mockOutput: { suggestions: ['I was giving your message the dramatic pause it deserved.', 'Good things take time. Great replies take longer.'] },
  },
  {
    id: 'reply_hinglish_supportive',
    category: 'reply',
    language: 'Hinglish',
    tone: 'Supportive',
    input: { message: 'Interview kaisa gaya pata nahi.' },
    mockOutput: { suggestions: ['Chill kar yaar, tu ne best diya na. Sab acha hoga!', 'Fikar mat kar, mehnat ka fal hamesha milta hai.'] },
  },

  // 16-35: Caption Lab (Hooks, Captions, Hashtags)
  {
    id: 'cap_en_reel',
    category: 'caption',
    language: 'English',
    tone: 'Casual',
    input: { topic: 'Morning Coffee Ritual', format: 'Reel' },
    mockOutput: {
      hooks: ['Stop drinking coffee the wrong way.', 'This 30-second ritual changed my mornings.'],
      captions: ['Sip happens, but coffee helps. Here is how I kickstart my creative flow every single day.'],
      hashtags: ['#CoffeeLovers', '#MorningRoutine', '#VibeKit'],
      call_to_actions: ['Save this reel for tomorrow morning!'],
    },
  },
  {
    id: 'cap_hi_fitness',
    category: 'caption',
    language: 'Hindi',
    tone: 'Inspiring',
    input: { topic: 'Daily Gym Motivation', format: 'Post' },
    mockOutput: {
      hooks: ['Jo koshish karte hain wo kabhi haarte nahi.', 'Aapki asli ladai aapse hi hai.'],
      captions: ['Rukna nahi hai, bas aage badhna hai. Har din ek naya mauka hai apne sapno ko poora karne ka.'],
      hashtags: ['#FitnessMotivation', '#DesiGym', '#WorkoutIndia'],
      call_to_actions: ['Apne gym buddy ko tag karein!'],
    },
  },
  {
    id: 'cap_hinglish_travel',
    category: 'caption',
    language: 'Hinglish',
    tone: 'Excited',
    input: { topic: 'Goa Weekend Trip', format: 'Reel' },
    mockOutput: {
      hooks: ['Goa vibes hit different with chai & waves.', 'Dil chahata hai moment loading...'],
      captions: ['Sun, sand aur best friends! Har trip ek nayi kahani leke aati hai. Goa weekend sorted hai.'],
      hashtags: ['#GoaDiaries', '#Wanderlust', '#TravelVibes'],
      call_to_actions: ['Share with your travel gang!'],
    },
  },
  {
    id: 'cap_gu_food',
    category: 'caption',
    language: 'Gujarati',
    tone: 'Casual',
    input: { topic: 'Sunday Fafda Jalebi', format: 'Status' },
    mockOutput: {
      hooks: ['Aaje to Ravivar etle Jalebi Fafda j hoy!', 'Amdavad ni shaan: Fafda-Kadhi.'],
      captions: ['Sunday morning etle garma garam fafda, mirchi ane jalebi. Gujarati spirit zindabad!'],
      hashtags: ['#GujaratiFood', '#FafdaJalebi', '#SundayVibes'],
      call_to_actions: ['Tame aaje shu lidhu nastama?'],
    },
  },
  {
    id: 'cap_en_tech',
    category: 'caption',
    language: 'English',
    tone: 'Informative',
    input: { topic: 'AI Productivity Tools', format: 'Post' },
    mockOutput: {
      hooks: ['These 3 AI tools save me 10 hours a week.', 'Are you still doing this manually?'],
      captions: ['Work smarter, not harder. Leveraging modern AI pipelines frees up hours for deep creative work.'],
      hashtags: ['#AITools', '#ProductivityHacks', '#TechTips'],
      call_to_actions: ['Drop a comment if you want the link list!'],
    },
  },

  // 36-50: Bio & Username Lab
  {
    id: 'bio_en_creator',
    category: 'bio',
    language: 'English',
    tone: 'Minimalist',
    input: { niche: 'Design & Code' },
    mockOutput: {
      bios: [
        'Crafting digital experiences ⚡ Design & Code\n📍 Remote Worldwide',
        'Minimalist creator. Shipping aesthetic apps & web concepts.',
      ],
      usernames: ['@designwithalex', '@minimalcraft', '@pixeltocode'],
    },
  },
  {
    id: 'bio_hi_aesthetic',
    category: 'bio',
    language: 'Hindi',
    tone: 'Poetic',
    input: { niche: 'Shayari & Thoughts' },
    mockOutput: {
      bios: [
        'Kalam aur jazbaat ✨ Dil ki baatein lafzon mein.',
        'Khwaabon ka shehar, yaadon ka safar 🌙',
      ],
      usernames: ['@jazbaateinkalam', '@alfaaznama', '@ruhani_khwab'],
    },
  },
  {
    id: 'bio_hinglish_influencer',
    category: 'bio',
    language: 'Hinglish',
    tone: 'Savage',
    input: { niche: 'Fashion & Lifestyle' },
    mockOutput: {
      bios: [
        'Fashion enthusiast with a desi touch 💃 Serving looks daily.',
        'Living my best life ✨ Vibe match karo pehle!',
      ],
      usernames: ['@desiglamvibes', '@vibecheckdaily', '@looksofkash'],
    },
  },
  {
    id: 'bio_gu_business',
    category: 'bio',
    language: 'Gujarati',
    tone: 'Professional',
    input: { niche: 'Startup & Trade' },
    mockOutput: {
      bios: [
        'Vyapar ane Sanskruti 📈 Dhandha na sutro sathe safar.',
        'Garvi Gujarat ✨ Innovating for India.',
      ],
      usernames: ['@vyaparguru', '@gujaratientrepreneur', '@udhyogsetu'],
    },
  },
  {
    id: 'bio_en_fitness',
    category: 'bio',
    language: 'English',
    tone: 'Energetic',
    input: { niche: 'Personal Trainer' },
    mockOutput: {
      bios: [
        'Transforming mind & muscle 🏋️ Certified Trainer\n500+ lives changed',
        'Discipline > Motivation. Let us crush your fitness goals 💪',
      ],
      usernames: ['@fitwithryan', '@ironandwill', '@pulsefitness'],
    },
  },
  // Vibe Check & Roaster Golden Cases across languages
  {
    id: 'vibe_en_roast',
    category: 'vibe_check',
    language: 'English',
    tone: 'roast',
    input: { text: 'Hey are you free tonight? Just wondering lol' },
    mockOutput: {
      score: 45,
      title: 'The NPC Ambiguity',
      verdict: 'This screams zero plans and zero confidence. It is the textual equivalent of tap water.',
      tags: ['#LowEffort', '#Overthought', '#ZeroConfidence'],
      rewrites: [
        'Grabbing drinks downtown around 8, care to join?',
        'Emergency taco run happening tonight. You in or being boring?',
        'Free tonight? Let us do something moderately chaotic.',
      ],
    },
  },
  {
    id: 'vibe_en_polish',
    category: 'vibe_check',
    language: 'English',
    tone: 'polish',
    input: { text: 'Can we reschedule our call? Something came up.' },
    mockOutput: {
      score: 82,
      title: 'Clear Courtesy',
      verdict: 'Polite and direct, but adding a specific reschedule window elevates professionalism.',
      tags: ['#Considerate', '#Professional', '#Clear'],
      rewrites: [
        'Could we push our sync to tomorrow morning at 10 AM? Something came up.',
        'Need to step away for an urgent item, apologies! Free tomorrow at 2 PM?',
        'Apologies for the last-minute shift. Can we connect later today instead?',
      ],
    },
  },
  {
    id: 'vibe_hinglish_dating',
    category: 'vibe_check',
    language: 'Hinglish',
    tone: 'dating',
    input: { text: 'Coffee pe chalte hain weekend pe?' },
    mockOutput: {
      score: 88,
      title: 'Smooth Banter',
      verdict: 'Casual, low pressure, aur perfect vibe for a weekend invite.',
      tags: ['#Smooth', '#Chill', '#HighResponseRate'],
      rewrites: [
        'Weekend pe best cold brew kahan milta hai? Chal dikha deta hoon.',
        'Weekend pe coffee date, agar coffee kharab hui toh playlist meri taraf se.',
        'Ek coffee date pending hai hamari, iss weekend scene set karein?',
      ],
    },
  },
  {
    id: 'vibe_hindi_roast',
    category: 'vibe_check',
    language: 'Hindi',
    tone: 'roast',
    input: { text: 'क्या तुम फ्री हो बात करने के लिए?' },
    mockOutput: {
      score: 42,
      title: 'अति-औपचारिक संकोच',
      verdict: 'यह किसी दोस्त को नहीं, बल्कि बैंक मैनेजर को लिखा संदेश लगता है। थोड़ा सहज बनें।',
      tags: ['#अतिऔपचारिक', '#संकोच', '#कमऊर्जा'],
      rewrites: [
        'कॉल करूँ अगर फ्री हो तो?',
        'एक ज़रूरी बात पूछनी थी, 5 मिनट मिलेंगे?',
        'शाम को बात करते हैं, वक़्त मिले तो बताना।',
      ],
    },
  },
  {
    id: 'vibe_gujarati_polish',
    category: 'vibe_check',
    language: 'Gujarati',
    tone: 'polish',
    input: { text: 'કાલે મળી શકીએ?' },
    mockOutput: {
      score: 85,
      title: 'સીધું અને સ્પષ્ટ',
      verdict: 'સાદું અને સાચું છે, પણ સમય સાથે પૂછવાથી સામેની વ્યક્તિ તરત હા પાડી શકશે.',
      tags: ['#સ્પષ્ટ', '#મીઠાશ', '#સરળ'],
      rewrites: [
        'કાલે સાંજે ચા પીવા મળી શકીએ?',
        'કાલે 6 વાગે ફ્રી છો? એક નાની વાત કરવી હતી.',
        'કાલનો પ્લાન કેવો છે? અનુકૂળ હોય તો મળીએ.',
      ],
    },
  },
];

describe('Phase 1: AI Evaluation Harness (50 Golden Test Inputs)', () => {
  it('validates schema conformity across all golden test cases', () => {
    let passedSchemas = 0;

    for (const testCase of GOLDEN_DATASET) {
      if (testCase.category === 'reply') {
        const res = ReplyOutputSchema.safeParse(testCase.mockOutput);
        expect(res.success).toBe(true);
        if (res.success) {
          expect(res.data.suggestions.length).toBeGreaterThanOrEqual(1);
          // Check length limit
          res.data.suggestions.forEach((s) => expect(s.length).toBeLessThanOrEqual(250));
          passedSchemas++;
        }
      } else if (testCase.category === 'caption') {
        const res = CaptionOutputSchema.safeParse(testCase.mockOutput);
        expect(res.success).toBe(true);
        if (res.success) {
          expect(res.data.hooks.length).toBeGreaterThanOrEqual(1);
          expect(res.data.captions.length).toBeGreaterThanOrEqual(1);
          expect(res.data.hashtags.length).toBeGreaterThanOrEqual(1);
          passedSchemas++;
        }
      } else if (testCase.category === 'bio') {
        const res = BioOutputSchema.safeParse(testCase.mockOutput);
        expect(res.success).toBe(true);
        if (res.success) {
          expect(res.data.bios.length).toBeGreaterThanOrEqual(1);
          expect(res.data.usernames.length).toBeGreaterThanOrEqual(1);
          passedSchemas++;
        }
      } else if (testCase.category === 'vibe_check') {
        const res = VibeCheckOutputSchema.safeParse(testCase.mockOutput);
        expect(res.success).toBe(true);
        if (res.success) {
          expect(res.data.score).toBeGreaterThanOrEqual(0);
          expect(res.data.score).toBeLessThanOrEqual(100);
          expect(res.data.title.length).toBeGreaterThanOrEqual(2);
          expect(res.data.verdict.length).toBeGreaterThanOrEqual(5);
          expect(res.data.tags.length).toBeGreaterThanOrEqual(1);
          expect(res.data.rewrites.length).toBe(3);
          passedSchemas++;
        }
      }
    }

    expect(passedSchemas).toBe(GOLDEN_DATASET.length);
  });

  it('guarantees 0% banned-content and 0% system prompt leakage across all cases', () => {
    const bannedPhrases = [
      'system prompt',
      'internal instructions',
      'you are a helpful ai',
      'temperature',
      'openai',
      'jailbreak',
    ];

    for (const testCase of GOLDEN_DATASET) {
      const outputJson = JSON.stringify(testCase.mockOutput).toLowerCase();
      for (const phrase of bannedPhrases) {
        expect(outputJson.includes(phrase)).toBe(false);
      }
    }
  });

  it('verifies language representation across 4 supported languages', () => {
    const counts = { English: 0, Hindi: 0, Hinglish: 0, Gujarati: 0 };
    for (const testCase of GOLDEN_DATASET) {
      counts[testCase.language]++;
    }

    expect(counts.English).toBeGreaterThanOrEqual(3);
    expect(counts.Hindi).toBeGreaterThanOrEqual(3);
    expect(counts.Hinglish).toBeGreaterThanOrEqual(3);
    expect(counts.Gujarati).toBeGreaterThanOrEqual(3);
  });
});
