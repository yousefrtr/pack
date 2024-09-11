library flutter_pkg;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class speechToTextBtn extends StatefulWidget {
  speechToTextBtn(
      {required this.child,
      required this.theText,
      required this.isEn,
      super.key});
  final bool isEn;
  final ValueChanged<String> theText;
  final Widget child;

  @override
  State<speechToTextBtn> createState() => _speechToTextBtnState();
}

class _speechToTextBtnState extends State<speechToTextBtn> {
  final SpeechToText speechToText = SpeechToText();
  final vosk = VoskFlutterPlugin.instance();
  final modelLoader = ModelLoader();
  final sampleRate = 16000;
  Model? model;
  Future<bool> isAndroidGoogleNotSupportedBool = isAndroidGoogleNotSupported();

  Recognizer? recognizer;
  SpeechService? speechService;
  bool recognitionStarted = false;

  StreamSubscription? subscription;
  var loadData = true;
  String fullText = "";
  @override
  void initState() async {
    await isAndroidGoogleNotSupportedBool ? loadModel() : null;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: startStopdRecord,
      child: widget.child,
    );
  }

  void loadModel() async {
    if (await modelLoader.isModelAlreadyLoaded(widget.isEn
        ? "vosk-model-small-en-us-0.15"
        : "vosk-model-ar-mgb2-0.4")) {
      try {
        setState(() async {
          var modelCreate = vosk.createModel(await modelLoader.modelPath(
              widget.isEn
                  ? "vosk-model-small-en-us-0.15"
                  : "vosk-model-ar-mgb2-0.4"));

          model = await modelCreate;

          var createRecognizer = vosk.createRecognizer(
            model: model!,
            sampleRate: sampleRate,
          );

          recognizer = await createRecognizer;
        });

        initspeechService();
      } catch (e) {
        print(e);
      }
    } else {
      setState(() async {
        loadData = true;

        var loadModel = modelLoader
            .loadModelsList()
            .then((modelsList) => modelsList.firstWhere((model) =>
                model.name ==
                (widget.isEn
                    ? "vosk-model-small-en-us-0.15"
                    : "vosk-model-ar-mgb2-0.4")))
            .then((modelDescription) =>
                modelLoader.loadFromNetwork(modelDescription.url));

        var modelCreate = vosk.createModel(await loadModel);

        model = await modelCreate;

        loadData = false;

        var createRecognizer =
            vosk.createRecognizer(model: model!, sampleRate: sampleRate);

        recognizer = await createRecognizer;
      });

      initspeechService();
    }
  }

  void initspeechService() async {
    if (speechService == null) {
      try {
        speechService = await vosk.initSpeechService(recognizer!);
      } catch (e) {
        if (e.toString() ==
            "PlatformException(INITIALIZE_FAIL, SpeechService instance already exist., null, null)") {
          setState(() {
            speechService = vosk.getSpeechService();
          });
        } else {
          print(e);
          print("object");
        }
      }
    }
  }

  void startStopdRecord() async {
    await isAndroidGoogleNotSupportedBool
        ? startStopdRecordNotSuportedGoogle()
        : startStopRecordSuportedGoogle();
    setState(() {
      recognitionStarted = !recognitionStarted;
    });
  }

  void startStopdRecordNotSuportedGoogle() async {
    if (recognitionStarted) {
      await speechService?.stop();

      subscription?.cancel();
    } else {
      await speechService!.start();
      setState(() {
        fullText = "";
        subscription = speechService?.onResult().listen(
              (Value) => widget.theText(ResultNotSuportedGoogle(Value)),
            );
      });
    }
  }

  void startStopRecordSuportedGoogle() async {
    if (recognitionStarted) {
      setState(() async {
        await speechToText.stop();
      });
    } else {
      await speechToText.listen(
        onResult: (result) => widget.theText(ResultSuportedGoogle(result)),
        localeId: widget.isEn ? "en-US" : "ar-SA",
      );
      setState(() {
        fullText = "";
      });
    }
    setState(() {
      recognitionStarted = !recognitionStarted;
    });
  }

  String ResultNotSuportedGoogle(
    String Result,
  ) {
    var str = (jsonDecode(Result));

    var newStr = str.text ?? "";
    if (newStr.isNotEmpty) {
      setState(() {
        fullText += " " + newStr;
      });
    }
    return fullText;
  }

  String ResultSuportedGoogle(SpeechRecognitionResult Result) {
    setState(() {
      fullText = Result.recognizedWords;
    });
    return fullText;
  }
}

Future<bool> isAndroidGoogleNotSupported() async {
  // Check if the platform is Android
  if (!Platform.isAndroid) return false;

  // Attempt to get information about Google Play services
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    // Logic to check Google services support, this could involve checking packageInfo or other means.
    // For example, you could add checks for Google Play Store or related services.

    // Assuming a custom condition for demonstration:
    bool googleServicesSupported = true; // Replace this with actual check logic

    return !googleServicesSupported; // Return true if Google services are not supported
  } on PlatformException {
    // Handle the error and return that Google services are not supported
    return true; // Default to not supported if there's an error
  }
}
