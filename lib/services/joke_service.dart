import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JokeService {
  static const String _url =
      'https://v2.jokeapi.dev/joke/Programming?blacklistFlags=nsfw,religious,political,racist,sexist,explicit&amount=10';
  static const String _usedJokesKey = 'used_local_jokes';

  /// Fetches fresh English jokes from the web, mixes them with unused 
  /// local Hinglish/Marathi jokes. Once local jokes are exhausted, 
  /// only uses the web API.
  static Future<List<String>> fetchJokes({int count = 10}) async {
    final List<String> jokesToReturn = [];

    final prefs = await SharedPreferences.getInstance();
    final jokeLanguage = prefs.getString('joke_language') ?? 'Mixed';

    // 1. Fetch fresh web jokes (English)
    if (jokeLanguage == 'English' || jokeLanguage == 'Mixed') {
      try {
        final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['error'] == false) {
            if (data['jokes'] != null) {
              final List<dynamic> jokesData = data['jokes'];
              for (var j in jokesData) {
                if (j['type'] == 'single') {
                  jokesToReturn.add(j['joke'].toString());
                } else if (j['type'] == 'twopart') {
                  jokesToReturn.add('${j['setup']}\n\n${j['delivery']}');
                }
              }
            } else {
              if (data['type'] == 'single') {
                jokesToReturn.add(data['joke'].toString());
              } else if (data['type'] == 'twopart') {
                jokesToReturn.add('${data['setup']}\n\n${data['delivery']}');
              }
            }
          }
        }
      } catch (_) {
        // Ignore API failure
      }
    }

    // 2. Massive list of local relatable Hindi jokes (Devanagari)
    if (jokeLanguage == 'Hindi' || jokeLanguage == 'Mixed') {
      final List<String> localJokes = [
        "टीचर: 'होमवर्क क्यों नहीं किया?'\nस्टूडेंट: 'मैम, मैं हॉस्टल में रहता हूँ।'\nटीचर: 'तो?'\nस्टूडेंट: 'हॉस्टल में तो हॉस्टल वर्क करना चाहिए ना!'",
        "पत्नी: 'सुनो जी, जब हमारी नई-नई शादी हुई थी, तब तो आप मुझे बहुत प्यार करते थे, अब क्या हो गया?'\nपति: 'अरे पगली, चुनाव खत्म होने के बाद कौन प्रचार करता है!'",
        "बॉस: 'तुम ऑफिस में सो क्यों रहे हो?'\nकर्मचारी: 'सर, मैं सो नहीं रहा हूँ, बल्कि आंखें बंद करके कंपनी के बड़े लक्ष्यों के बारे में सोच रहा हूँ।'",
        "लड़का: 'मुझे तुमसे प्यार है।'\nलड़की: 'लेकिन मेरे पास तो बॉयफ्रेंड है।'\nलड़का: 'कोई बात नहीं, मुझे भी कौन सा शादी करनी है, मुझे तो बस टाइम पास करना है।'",
        "डॉक्टर: 'आपका वजन कम करना बहुत जरूरी है।'\nमरीज: 'ठीक है डॉक्टर साहब, मैं कल से रोज 10 किलोमीटर चलूंगा।'\nएक हफ्ते बाद... मरीज: 'डॉक्टर साहब, मैं तो 70 किलोमीटर दूर आ गया, अब वापस कैसे जाऊं?'",
        "भिखारी: 'भगवान के नाम पर कुछ दे दे बाबा।'\nआदमी: 'ये लो, मेरी पत्नी को ले जाओ।'\nभिखारी: 'अरे बाबा, मैंने कुछ देने को कहा था, मेरी जिंदगी बर्बाद करने को नहीं!'",
        "बेटा: 'पापा, मुझे बुलेट चाहिए।'\nपापा: 'पड़ोस वाले शर्मा जी की लड़की को देख, वो बस से जाती है।'\nबेटा: 'वही तो नहीं देखी जाती पापा!'",
        "पति: 'आज खाने में क्या बनाया है?'\nपत्नी: 'जो तुम कहो।'\nपति: 'दाल मखनी बना लो।'\nपत्नी: 'वो तो कल बनाई थी।'\nपति: 'तो फिर मटर पनीर बना लो।'\nपत्नी: 'वो तो मुझे पसंद नहीं।'\nपति: 'तो फिर जो मर्जी हो बना लो!'\nपत्नी: 'वही तो पूछ रही हूँ, क्या बनाऊँ?'",
        "एक मच्छर परेशान बैठा था।\nदूसरे ने पूछा: 'क्या हुआ?'\nपहला: 'यार, गजब हो रहा है। चूहेदानी में चूहा, छिपकलीदानी में छिपकली... लेकिन मच्छरदानी में इंसान सो रहा है!'",
        "टीचर: 'बताओ, दुनिया में सबसे पुरानी चीज क्या है?'\nस्टूडेंट: 'सर, गुस्सा!'\nटीचर: 'कैसे?'\nस्टूडेंट: 'जब से इंसान पैदा हुआ है, तब से ही नाक पर रखा है!'",
        "पत्नी: 'अजी सुनते हो, मेरी नई सहेली आई है, मैं उससे मिलने जा रही हूँ।'\nपति: 'ठीक है, जाओ।'\nपत्नी: 'अरे, आप मुझे रोकेंगे नहीं?'\nपति: 'मैं कौन होता हूँ रोकने वाला? जो अपनी मर्जी से आई है, वो अपनी मर्जी से जाएगी!'",
        "लड़की (बॉयफ्रेंड से): 'जानू, तुम मुझे कितना प्यार करते हो?'\nबॉयफ्रेंड: 'जितना तुम मुझे करती हो।'\nलड़की: 'हाय राम! इसका मतलब तुम भी मेरे साथ टाइम पास कर रहे हो!'",
        "बेटा: 'पापा, आज मुझे एक लड़की ने किस किया!'\nपापा: 'वाह बेटा! क्या बात है!'\nबेटा: 'हाँ पापा, उसने कहा कि तुम बिल्कुल अपने पापा जैसे दिखते हो!'",
        "मास्टर जी: 'बच्चों, बताओ, अगर पृथ्वी गोल है, तो हम गिरते क्यों नहीं?'\nपप्पू: 'सर, क्योंकि हम अंदर की तरफ हैं!'\nमास्टर जी: 'अरे बेवकूफ, अंदर कैसे?'\nपप्पू: 'सर, अगर बाहर होते तो हमें दिखाई नहीं देता कि पृथ्वी गोल है!'",
        "संता: 'यार बंता, मेरी बीवी बहुत खर्चीली है।'\nबंता: 'क्यों, क्या हुआ?'\nसंता: 'कल कहने लगी कि मुझे सोने की चेन चाहिए।'\nबंता: 'तो तूने क्या किया?'\nसंता: 'मैंने उसे लोहे की चेन दे दी और कहा कि सोने के लिए यही काफी है!'",
        "डॉक्टर: 'तुम्हारी एक किडनी फेल हो गई है।'\nमरीज: 'डॉक्टर साहब, दूसरी का रिजल्ट कब आएगा?'",
        "टीचर: 'बच्चों, बताओ, 'I love you' का आविष्कार किसने किया?'\nस्टूडेंट: 'सर, चीन ने!'\nटीचर: 'कैसे?'\nस्टूडेंट: 'क्योंकि इसमें कोई गारंटी नहीं होती, चले तो चाँद तक, नहीं तो शाम तक!'",
        "पत्नी: 'सुनो जी, मैं सोच रही हूँ कि मैं भी नौकरी कर लूँ।'\nपति: 'ठीक है, कर लो।'\nपत्नी: 'तो फिर घर का काम कौन करेगा?'\nपति: 'तुम ही करोगी, क्योंकि नौकरी तो तुम सिर्फ 8 घंटे करोगी ना!'",
        "लड़का: 'मुझे ऐसी लड़की चाहिए जो मुझे समझ सके।'\nदोस्त: 'भाई, अगर वो तुझे समझ गई, तो वो तुझे कभी नहीं चुनेगी!'",
        "बॉस: 'तुम हमेशा लेट क्यों आते हो?'\nकर्मचारी: 'सर, मैं हमेशा लेट नहीं आता, बस आप हमेशा जल्दी आ जाते हैं!'",
        "टीचर: 'एक वाक्य बनाओ जिसमें 'शायद' और 'ज़रूर' दोनों हों।'\nछात्र: 'शायद आज बारिश ज़रूर होगी!'",
        "पत्नी: 'अगर मैं मर गई तो तुम क्या करोगे?'\nपति: 'मैं भी मर जाऊँगा!'\nपत्नी: 'क्यों?'\nपति: 'क्योंकि इतनी खुशी मैं बर्दाश्त नहीं कर पाऊँगा!'"
      ];

      // 3. Track used local jokes to prevent repetition
      final usedIndexesStr = prefs.getStringList(_usedJokesKey) ?? [];
      final Set<int> usedIndexes = usedIndexesStr.map((e) => int.parse(e)).toSet();

      // Find which local jokes are still unused
      final List<int> unusedIndexes = [];
      for (int i = 0; i < localJokes.length; i++) {
        if (!usedIndexes.contains(i)) {
          unusedIndexes.add(i);
        }
      }

      // If we ran out of local jokes, clear the used list to start over
      if (unusedIndexes.isEmpty) {
        usedIndexes.clear();
        for (int i = 0; i < localJokes.length; i++) {
          unusedIndexes.add(i);
        }
      }

      // 4. Pick some local jokes
      unusedIndexes.shuffle(Random());
      final pickCount = min(jokeLanguage == 'Hindi' ? count : 5, unusedIndexes.length);
      final picked = unusedIndexes.take(pickCount).toList();

      for (var idx in picked) {
        jokesToReturn.add(localJokes[idx]);
        usedIndexes.add(idx); // Mark as used
      }

      // Save the updated used list back to storage
      await prefs.setStringList(
        _usedJokesKey,
        usedIndexes.map((e) => e.toString()).toList(),
      );
    }

    // 5. Shuffle the combined list (API + Local)
    jokesToReturn.shuffle(Random());
    
    // Fallback if everything fails
    if (jokesToReturn.isEmpty) {
      jokesToReturn.add("Why do programmers prefer dark mode? Because light attracts bugs.");
    }
    
    return jokesToReturn.take(count).toList();
  }
}


