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
      {required this.startedRecordChild,
      required this.stopedRecordChild,
      required this.theText,
      required this.isEnglish,
      super.key});

  ///The Language Arabic Or English If it's Arabic [isEnglish]=false else if it's English [isEnglish]=true
  final bool isEnglish;

  /// You Need String In ValueChanged Function YourString=Valu in [theText] ValueChanged
  final ValueChanged<String> theText;

  /// That Is The Wedgit In The Mic Stop Record
  final Widget startedRecordChild;

  /// That Is The Wedgit In The Mic Start Record
  final Widget stopedRecordChild;

  @override
  State<speechToTextBtn> createState() => _speechToTextBtnState();
}

class _speechToTextBtnState extends State<speechToTextBtn> {
  final SpeechToText speechToText = SpeechToText();
  final vosk = VoskFlutterPlugin.instance();
  final modelLoader = ModelLoader();
  final sampleRate = 16000;
  Model? model;

  /// If Do You Want The Btn For Mobils Not Suported By Google That Is Availabale
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
        child: recognitionStarted
            ? widget.startedRecordChild
            : widget.stopedRecordChild);
  }

  void loadModel() async {
    if (await modelLoader.isModelAlreadyLoaded(widget.isEnglish
        ? "vosk-model-small-en-us-0.15"
        : "vosk-model-ar-mgb2-0.4")) {
      try {
        setState(() async {
          var modelCreate = vosk.createModel(await modelLoader.modelPath(
              widget.isEnglish
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
                (widget.isEnglish
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
      setState(() async {
        await speechToText.listen(
          onResult: (result) => widget.theText(ResultSuportedGoogle(result)),
          localeId: widget.isEnglish ? "en-US" : "ar-SA",
        );
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

  try {
    await PackageInfo.fromPlatform();

    bool googleServicesSupported = true;

    return !googleServicesSupported;
  } on PlatformException {
    return true;
  }
}
