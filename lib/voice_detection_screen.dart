import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'sos_screen.dart';
import 'ai_guardian_service.dart';

class VoiceDetectionScreen extends StatefulWidget {
  const VoiceDetectionScreen({super.key});

  @override
  State<VoiceDetectionScreen> createState() => _VoiceDetectionScreenState();
}

class _VoiceDetectionScreenState extends State<VoiceDetectionScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  String _spokenText = "Press Start Listening or say 'Help' / 'Help Me'";

  Future<void> startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint("Speech Status : $status");
      },
      onError: (error) {
        debugPrint("Speech Error : ${error.errorMsg}");
      },
    );

    if (!available) {
      setState(() {
        _spokenText = "Speech Recognition Not Available";
      });
      return;
    }

    setState(() {
      _isListening = true;
      _spokenText = "Listening for emergency voice command...";
    });

    AIGuardianService.instance.updateVoiceSignal(
      state: VoiceSignalState.listening,
    );

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
      ),
      onResult: (result) {
        setState(() {
          _spokenText = result.recognizedWords;
        });

        String text = result.recognizedWords.toLowerCase();

        if (text.contains("help") ||
            text.contains("help me") ||
            text.contains("save me") ||
            text.contains("sos") ||
            text.contains("emergency") ||
            text.contains("please help")) {
          // Notify AI Guardian of verified keyword
          AIGuardianService.instance.updateVoiceSignal(
            state: VoiceSignalState.keywordDetected,
            recognizedWords: result.recognizedWords,
          );

          _speech.stop();

          setState(() {
            _isListening = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SosScreen(),
            ),
          );
        } else {
          AIGuardianService.instance.updateVoiceSignal(
            state: VoiceSignalState.normal,
            recognizedWords: result.recognizedWords,
          );
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();

    AIGuardianService.instance.updateVoiceSignal(
      state: VoiceSignalState.normal,
    );

    setState(() {
      _isListening = false;
      _spokenText = "Press Start Listening";
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Detection"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.red.withValues(alpha: 0.15)
                      : Colors.deepPurple.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.deepPurple,
                  size: 90,
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _spokenText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  if (_isListening) {
                    stopListening();
                  } else {
                    startListening();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isListening ? Colors.red : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                ),
                label: Text(
                  _isListening
                      ? "Stop Listening"
                      : "Start Voice Detection",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}