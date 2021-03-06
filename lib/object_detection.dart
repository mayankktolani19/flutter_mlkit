import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'texts.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';

const String ssd = "SSD MobileNet";
const String yolo = "Tiny Yolov2";

class ObjectDetector extends StatefulWidget {
  @override
  _ObjectDetectorState createState() => _ObjectDetectorState();
}

class _ObjectDetectorState extends State<ObjectDetector> {
  String _model = ssd;
  File _image;
  double _imageWidth, _imageHeight;
  bool _busy = false, _gallery = true, showSpinner = false;
  List _recognitions;
  var color1 = Color.fromRGBO(0, 15, 200, 10),
      color2 = Color.fromRGBO(120, 20, 150, 10);

  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yolo) {
        res = await Tflite.loadModel(
            model: "assets/tflite/yolov2_tiny.tflite",
            labels: "assets/tflite/yolov2_tiny.txt");
      } else {
        res = await Tflite.loadModel(
            model: "assets/tflite/ssd_mobilenet.tflite",
            labels: "assets/tflite/ssd_mobilenet.txt");
      }
    } on PlatformException {
      print("Failed to load model.");
    }
  }

  selectFromImagePicker() async {
    setState(() {
      showSpinner = true;
    });
    var image;
    if (_gallery)
      image = await ImagePicker.pickImage(source: ImageSource.gallery);
    else
      image = await ImagePicker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    setState(() {
      _busy = true;
      color1 = Color.fromRGBO(0, 15, 0, 10);
      color2 = Color.fromRGBO(0, 10, 45, 10);
    });
    predictImage(image);
    setState(() {
      showSpinner = false;
    });
  }

  predictImage(File image) async {
    if (image == null) return;
    if (_model == yolo) {
      await yolov2Tiny(image);
    } else {
      await ssdMobileNet(image);
    }
    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        })));
    setState(() {
      _image = image;
      _busy = false;
    });
  }

  yolov2Tiny(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        model: "YOLO",
        threshold: 0.3,
        imageMean: 0.0,
        imageStd: 255.0,
        numResultsPerClass: 1);
    setState(() {
      _recognitions = recognitions;
    });
  }

  ssdMobileNet(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path, numResultsPerClass: 1, threshold: 0.15);
    setState(() {
      _recognitions = recognitions;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];
    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;
    Color blue = Colors.blue;
    return _recognitions.map((re) {
      if (re["confidenceInClass"] >= 0.35) {
        return Positioned(
          left: re["rect"]["x"] * factorX,
          top: re["rect"]["y"] * factorY,
          width: re["rect"]["w"] * factorX,
          height: re["rect"]["h"] * factorY,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: blue, width: 3),
            ),
            child: Text(
              "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)} %",
              style: TextStyle(
                background: Paint()..color = blue,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        );
      }
      return Container();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];
    stackChildren.add(Positioned(
      top: 0,
      left: 0,
      width: size.width,
      child: _image == null
          ? Column(
              children: <Widget>[
                Container(
                    margin: EdgeInsets.only(
                        top: 100, left: 25, right: 25, bottom: 40),
                    padding: EdgeInsets.all(10),
                    child: Texts(
                        'Oops.....No Object to Detect, Please select an Image.',
                        25)),
                Divider(color: Colors.grey),
              ],
            )
          : Image.file(_image),
    ));
    stackChildren.addAll(renderBoxes(size));
    if (_busy) {
      stackChildren.add(Center(child: CircularProgressIndicator()));
    }
    return ModalProgressHUD(
      inAsyncCall: showSpinner,
      child: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color1, color2])),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Texts('Object Detector', 18),
            backgroundColor: Colors.transparent,
          ),
          floatingActionButton: _getFAB(),
          body: Stack(
            children: stackChildren,
          ),
        ),
      ),
    );
  }

  Widget _getFAB() {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: IconThemeData(size: 22),
      backgroundColor: Colors.blueAccent,
      visible: true,
      curve: Curves.bounceIn,
      children: [
        SpeedDialChild(
            child: Icon(Icons.image),
            backgroundColor: Colors.blue,
            onTap: () {
              setState(() {
                _gallery = true;
              });
              selectFromImagePicker();
            },
            label: 'Pick from Gallery',
            labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 16.0),
            labelBackgroundColor: Colors.blue),
        SpeedDialChild(
            child: Icon(Icons.add_a_photo),
            backgroundColor: Colors.blue,
            onTap: () {
              setState(() {
                _gallery = false;
                selectFromImagePicker();
              });
            },
            label: 'Open Camera',
            labelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 16.0),
            labelBackgroundColor: Colors.blue)
      ],
    );
  }
}
