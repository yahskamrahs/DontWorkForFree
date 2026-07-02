import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JokeService {
  static const String _url =
      'https://v2.jokeapi.dev/joke/Programming,Pun,Miscellaneous?type=single&amount=10&safe-mode';
  static const String _usedJokesKey = 'used_local_jokes';

  /// Fetches fresh English jokes from the web, mixes them with unused 
  /// local Hinglish/Marathi jokes. Once local jokes are exhausted, 
  /// only uses the web API.
  static Future<List<String>> fetchJokes({int count = 10}) async {
    final List<String> jokesToReturn = [];

    // 1. Fetch fresh web jokes (Infinite variety)
    try {
      final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == false) {
          if (data['jokes'] != null) {
            final List<dynamic> jokesData = data['jokes'];
            jokesToReturn.addAll(jokesData.map((j) => j['joke'].toString()));
          } else if (data['joke'] != null) {
            jokesToReturn.add(data['joke'].toString());
          }
        }
      }
    } catch (_) {
      // Ignore API failure
    }

    // 2. Massive list of local relatable/trending Indian jokes
    final List<String> localJokes = [
      "HR: 'We are like a family here.'\nMe: 'Toh property mein hissa milega?'",
      "Manager: 'Why is this task delayed?'\nMe: 'Sir, work in progress sounds better than I forgot.'",
      "Salary credit message is the only 'I love you' an employee actually wants to hear.",
      "Client: 'I want it cheap, fast, and good.'\nMe: 'Pick two, aur teesre ka sapna chhod do.'",
      "Friday evening 5:59 PM...\nManager: 'Ek chota sa change hai...'\nMe: 🏃‍♂️💨",
      "Manager: 'Kaam kiti zala?'\nMe: 'Zala ki saheb... fkt suru karaycha baki ahe!'",
      "Pagar zalyawar 2 divas Ambani, baki 28 divas fakir. Hech tr ahe IT life!",
      "Client: 'He final ahe.'\nMe: 'Ho, tumchya pudhchya change paryant final ahe.'",
      "Friday sandhyakali manager cha msg ala ki vatat: Aata kai navin sankat aaloy?",
      "Code fatla ki devla devla karaycha, aani chalayla lagla ki 'I am the genius' mhanaycha.",
      "Me trying to save money.\nMy brain: Zomato pe discount hai bhai, aaj kha le.",
      "Friend: 'Weekend plan kay ahe?'\nMe: 'Zhop, khana, parat zhop.'",
      "Mumbai locals on Monday mornings are more crowded than my list of pending tasks.",
      "Me looking at my bank balance in the middle of the month: 'Yeh kahan aa gaye hum?'",
      "HR: 'Appraisal will be fair.'\nMe: 'Ha, aur Punit Superstar normal insan hai.'",
      "Auto walo ka attitude meri salary se bhi zyada high hai aaj kal.",
      "When someone says 'we need to talk'. My heart beat: 📈📈📈",
      "Manager: 'We need out of the box thinking.'\nMe: 'Sir, pehle box se bahar nikalne ka time toh do.'",
      "Pune traffic madhe signal var thambne mhanje eka janamchi tapascharya.",
      "Waking up at 7 AM feels like a punishment for a crime I didn't commit.",
      "My diet plan: I will start from Monday. (Repeat every Sunday night).",
      "Instagram reels banate waqt log bhool jate hai ki woh sadak pe khade hai.",
      "Logon ke paas iPhone 15 aa gaya, aur main abhi bhi apne phate hue charger pe tape laga raha hu.",
      "Every time my manager calls me randomly, I quickly open VS Code to look busy.",
      "Relatives: 'Beta aage ka kya socha hai?'\nMe: 'Bhook lagi hai, pehle khaana kha lu?'",
      "Meeting at 9 AM should be officially declared as a human rights violation.",
      "Boss: 'Consider me your friend.'\nAlso Boss: 'Yeh report 5 baje tak chahiye.'",
      "Me: 'I need a vacation.'\nBank Account: 'You need a glass of water, chup chap baith.'",
      "Chai is not just a drink in India, it's a solution to 99% of our problems.",
      "When the Wi-Fi stops working, I suddenly realize how lonely my life is.",
      "Dost: 'Bhai Goa chalte hai.'\nGoa plan: Cancelled since 2018.",
      "My only toxic trait is calculating how many hours of sleep I'll get if I sleep *right now*.",
      "Job lagne ke baad pata chala ki bachpan hi acha tha.",
      "That mini heart attack when you send a message to the wrong WhatsApp group.",
      "Corporate lingo translated:\n'Let's circle back' = 'I forgot what we were talking about'.",
      "Office AC is always set to 'Winter in Antarctica' mode.",
      "Me leaving work at exactly 5:00 PM: 🥷 stealth mode activated.",
      "When you fix a bug but 3 new bugs appear: 'Hum do, hamare do.'",
      "Told my mom I have a headache. She said it's because of my phone.",
      "Aai: 'Jevla ka?' The most powerful words in the world."
    ];

    // 3. Track used local jokes to prevent repetition
    final prefs = await SharedPreferences.getInstance();
    final usedIndexesStr = prefs.getStringList(_usedJokesKey) ?? [];
    final Set<int> usedIndexes = usedIndexesStr.map((e) => int.parse(e)).toSet();

    // Find which local jokes are still unused
    final List<int> unusedIndexes = [];
    for (int i = 0; i < localJokes.length; i++) {
      if (!usedIndexes.contains(i)) {
        unusedIndexes.add(i);
      }
    }

    // 4. If we have unused local jokes, pick some (e.g. up to 5)
    if (unusedIndexes.isNotEmpty) {
      unusedIndexes.shuffle(Random());
      final pickCount = min(5, unusedIndexes.length);
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


