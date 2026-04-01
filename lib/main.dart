import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:confetti/confetti.dart';

void main() => runApp(VocabMasterApp());

class VocabMasterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFDDE2E8),
        colorSchemeSeed: const Color(0xFF6D7687),
        useMaterial3: true,
      ),
      home: CategorySelectionScreen(),
    );
  }
}

class WordModel {
  final String category, bangla, arabic, urdu, english, pronunciation;
  WordModel({required this.category, required this.bangla, required this.arabic, 
            required this.urdu, required this.english, required this.pronunciation});
}

// Neumorphism Style Helper
BoxDecoration neuBox({bool inset = false, double radius = 20}) {
  return BoxDecoration(
    color: const Color(0xFFDDE2E8),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: inset 
      ? [
          const BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(4, 4), blurRadius: 8),
          const BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 8),
        ]
      : [
          const BoxShadow(color: Color(0xFFA3B1C6), offset: Offset(8, 8), blurRadius: 16),
          const BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-8, -8), blurRadius: 16),
        ],
  );
}

class CategorySelectionScreen extends StatefulWidget {
  @override
  _CategorySelectionScreenState createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  List<WordModel> allWords = [];
  String selectedLang = "bn"; 
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCSV();
  }

  Future<void> loadCSV() async {
    try {
      final rawData = await rootBundle.loadString('assets/word_data.csv');
      List<String> lines = rawData.split('\n');
      List<WordModel> temp = [];

      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        List<String> r = lines[i].split(',');
        if (r.length < 7) continue;
        temp.add(WordModel(
          category: r[1].trim(), 
          bangla: r[2].trim(), 
          arabic: r[3].trim(), 
          urdu: r[4].trim(), 
          english: r[5].trim(), 
          pronunciation: r[6].trim()
        ));
      }
      setState(() { allWords = temp; isLoading = false; });
    } catch (e) {
      debugPrint("Error loading CSV: $e");
    }
  }

  Map<String, List<WordModel>> getFilteredCategories() {
    Map<String, List<WordModel>> filtered = {};
    for (var word in allWords) {
      bool hasData = false;
      if (selectedLang == "bn" && word.bangla.isNotEmpty) hasData = true;
      if (selectedLang == "en" && word.english.isNotEmpty) hasData = true;
      if (selectedLang == "ur" && word.urdu.isNotEmpty) hasData = true;
      if (hasData) filtered.putIfAbsent(word.category, () => []).add(word);
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    var filteredData = getFilteredCategories();
    return Scaffold(
      body: SafeArea(
        child: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            const SizedBox(height: 20),
            const Text("Aduok Vocab Master", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF31344B))),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _langBtn("bn", "বাংলা"),
                  _langBtn("en", "English"),
                  _langBtn("ur", "اردو"),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredData.keys.length,
                itemBuilder: (context, index) {
                  String name = filteredData.keys.elementAt(index);
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => QuizEngine(words: filteredData[name]!, langCode: selectedLang, categoryName: name))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(20),
                      decoration: neuBox(),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book, color: Color(0xFF6D7687)),
                          const SizedBox(width: 15),
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          const Icon(Icons.play_arrow_rounded, color: Colors.blueGrey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langBtn(String code, String label) {
    bool isSel = selectedLang == code;
    return GestureDetector(
      onTap: () => setState(() => selectedLang = code),
      child: Container(
        width: 90, padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: neuBox(inset: isSel, radius: 15),
        child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.indigo : Colors.grey))),
      ),
    );
  }
}

class QuizEngine extends StatefulWidget {
  final List<WordModel> words;
  final String langCode;
  final String categoryName;
  QuizEngine({required this.words, required this.langCode, required this.categoryName});

  @override
  _QuizEngineState createState() => _QuizEngineState();
}

class _QuizEngineState extends State<QuizEngine> {
  late List<WordModel> sessionWords;
  int currentRound = 1, unlockedRound = 1, currentIdx = 0, score = 0;
  List<String> options = [];
  late ConfettiController _confetti;
  List<String> userBuiltWord = [];
  List<String> shuffledChars = [];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 1));
    sessionWords = List.from(widget.words)..shuffle();
    setupGame();
  }

  void setupGame() {
    var word = sessionWords[currentIdx];
    if (currentRound < 3) {
      String correct = currentRound == 1 ? _getLangTxt(word) : word.arabic;
      options = [correct];
      var random = Random();
      while (options.length < 4) {
        var w = widget.words[random.nextInt(widget.words.length)];
        String opt = currentRound == 1 ? _getLangTxt(w) : w.arabic;
        if (!options.contains(opt)) options.add(opt);
      }
      options.shuffle();
    } else {
      // আরবি অক্ষরগুলোকে আলাদা করা কিন্তু হারাকাতসহ রাখার চেষ্টা
      shuffledChars = word.arabic.split('')..shuffle();
      userBuiltWord = [];
    }
  }

  String _getLangTxt(WordModel w) {
    if (widget.langCode == "bn") return w.bangla;
    if (widget.langCode == "en") return "${w.english}\n(${w.pronunciation})";
    return w.urdu;
  }

  void checkAnswer(String selected) {
    String correct = currentRound == 1 ? _getLangTxt(sessionWords[currentIdx]) : sessionWords[currentIdx].arabic;
    if (selected == correct) {
      _confetti.play();
      setState(() => score += 10);
      Future.delayed(const Duration(milliseconds: 1000), nextStep);
    }
  }

  void nextStep() {
    if (currentIdx < sessionWords.length - 1) {
      setState(() { currentIdx++; setupGame(); });
    } else {
      _showRoundTransition();
    }
  }

  void _showRoundTransition() {
    if (unlockedRound == currentRound && unlockedRound < 3) unlockedRound++;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFDDE2E8),
        title: const Text("মাশাআল্লাহ! 🎉", textAlign: TextAlign.center),
        content: Text("আপনি রাউন্ড $currentRound সফলভাবে শেষ করেছেন।"),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            if (currentRound < 3) {
              setState(() { currentRound++; currentIdx = 0; sessionWords.shuffle(); setupGame(); });
            } else { Navigator.pop(context); }
          }, child: const Text("পরবর্তী ধাপ"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var word = sessionWords[currentIdx];
    double progress = (currentIdx + 1) / sessionWords.length;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.categoryName)),
      body: Stack(
        children: [
          Column(
            children: [
              // প্রোগ্রেস বার
              Container(
                height: 12, width: double.infinity, margin: const EdgeInsets.all(20),
                decoration: neuBox(inset: true, radius: 10),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.teal, Colors.greenAccent]), borderRadius: BorderRadius.circular(10))),
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _badge(1, "MCQ"), _badge(2, "Reverse"), _badge(3, "Builder"),
              ]),
              const SizedBox(height: 20),
              // কোশ্চেন কার্ড
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                width: double.infinity,
                decoration: neuBox(),
                // আরবির জন্য RTL এবং টেক্সট ডিরেকশন
                child: Directionality(
                  textDirection: currentRound == 1 ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    currentRound == 1 ? word.arabic : _getLangTxt(word), 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF31344B))
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (currentRound < 3) Expanded(child: ListView(children: options.map((o) => _optionItem(o)).toList())),
              if (currentRound == 3) _buildWordBuilder(word),
            ],
          ),
          Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confetti, blastDirectionality: BlastDirectionality.explosive)),
        ],
      ),
    );
  }

  Widget _badge(int r, String name) {
    bool active = currentRound == r;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: neuBox(inset: active, radius: 10),
      child: Text(name, style: TextStyle(fontSize: 11, color: active ? Colors.blue : Colors.grey)),
    );
  }

  Widget _optionItem(String txt) {
    return GestureDetector(
      onTap: () => checkAnswer(txt),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: neuBox(),
        child: Directionality(
          textDirection: currentRound == 2 ? TextDirection.rtl : TextDirection.ltr,
          child: Text(txt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
        ),
      ),
    );
  }

  // --- নতুন এবং উন্নত ওয়ার্ড বিল্ডার ---
  Widget _buildWordBuilder(WordModel word) {
    return Expanded(
      child: Column(children: [
        // এখানে অক্ষরগুলো যুক্ত হয়ে পূর্ণ শব্দ তৈরি হবে
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 25),
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: neuBox(inset: true, radius: 15),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              userBuiltWord.isEmpty ? "উপরে ক্লিক করুন" : userBuiltWord.join(''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: -1),
            ),
          ),
        ),
        const SizedBox(height: 30),
        // অক্ষর চয়ন করার বাটন
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Wrap(
            spacing: 12, runSpacing: 12,
            children: shuffledChars.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    userBuiltWord.add(entry.value);
                    if (userBuiltWord.join('') == word.arabic) {
                      _confetti.play();
                      score += 20;
                      Future.delayed(const Duration(seconds: 1), nextStep);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: neuBox(radius: 10),
                  child: Text(entry.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: () => setState(() => userBuiltWord = []), icon: const Icon(Icons.refresh, color: Colors.red)),
            const Text("আবার লিখুন", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}