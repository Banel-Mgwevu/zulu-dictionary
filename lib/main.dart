import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_azure_tts/flutter_azure_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

class DictionaryEntry {
  final String word;
  final String isizulu;
  final String definition;

  DictionaryEntry(
      {required this.word, required this.isizulu, required this.definition});

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'],
      isizulu: json['isizulu'],
      definition: json['definition'],
    );
  }
}

class DictionaryService {
  Future<List<DictionaryEntry>> getDictionary() async {
    final String jsonString =
        await rootBundle.loadString('assets/dictionary.json');
    final jsonData = json.decode(jsonString) as List<dynamic>;

    return jsonData.map((entry) => DictionaryEntry.fromJson(entry)).toList();
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.indigo,
        accentColor: Colors.amber,
        textTheme: TextTheme(
          bodyText1: TextStyle(color: Colors.black, fontSize: 16),
          bodyText2: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      home: DictionaryApp(),
    );
  }
}

class DictionaryApp extends StatefulWidget {
  @override
  _DictionaryAppState createState() => _DictionaryAppState();
}

class _DictionaryAppState extends State<DictionaryApp> {
  final DictionaryService _dictionaryService = DictionaryService();
  late List<DictionaryEntry> _dictionary;

  @override
  void initState() {
    super.initState();
    _loadDictionary();
    AzureTts.init(
    subscriptionKey: "935a507a40704fed86d4b57115f7ab59",
    region: "eastus",
    withLogs: true,
  );

  }

  Future<void> _loadDictionary() async {
    _dictionary = await _dictionaryService.getDictionary();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Word Explorer'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _dictionary == null
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _dictionary.length,
              itemBuilder: (context, index) {
                final entry = _dictionary[index];
                return Column(
                  children: [
                    if (index == 0 ||
                        _dictionary[index - 1].word[0] != entry.word[0])
                      ListTile(
                        title: Text(
                          entry.word[0],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(context).accentColor,
                          ),
                        ),
                      ),
                    Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                      child: ListTile(
                        title: Text(
                          entry.word,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18, // Adjust the font size as needed
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'isiZulu: ${entry.isizulu}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14, // Adjust the font size as needed
                              ),
                            ),
                            Text(
                              'Definition: ${entry.definition}',
                              style: TextStyle(
                                fontSize: 14, // Adjust the font size as needed
                              ),
                            ),
                          ],
                        ),
                        leading: Icon(Icons.book,
                            color: Theme.of(context).accentColor),
                        trailing: IconButton(
                          icon: Icon(Icons.volume_up),
                          onPressed: () {
                            _executeAzureTTS(entry.definition);
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => DefinitionScreen(entry)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class DefinitionScreen extends StatelessWidget {
  final DictionaryEntry entry;

  DefinitionScreen(this.entry);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.word),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'isiZulu: ${entry.isizulu}',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Definition: ${entry.definition}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                primary: Theme.of(context).accentColor,
              ),
              child: Text('Back to Dictionary'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _executeAzureTTS(String content) async {

  final voicesResponse = await AzureTts.getAvailableVoices();
  final voice = voicesResponse.voices.firstWhere(
    (element) => element.locale.startsWith("zu-ZA"),
    orElse: () => throw Exception('No English voices found'),
  );

  TtsParams params = TtsParams(
    voice: voice,
    audioFormat: AudioOutputFormat.audio16khz32kBitrateMonoMp3,
    rate: 1.5,
    text: content,
  );

  final ttsResponse = await AzureTts.getTts(params);
  final audioBytes = ttsResponse.audio.buffer.asUint8List();

  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/tts.mp3');
  await file.writeAsBytes(audioBytes);

  final audioPlayer = AudioPlayer();
  await audioPlayer.setFilePath(file.path);
  await audioPlayer.play();
}
