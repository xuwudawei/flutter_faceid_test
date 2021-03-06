import 'dart:convert';
import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as ImageLib;

class FaceIDCamera extends StatefulWidget {
  @override
  _FaceIDCameraState createState() => _FaceIDCameraState();
}

class _FaceIDCameraState extends State<FaceIDCamera> {
  List<CameraDescription> cameras;
  CameraController cameraController;
  var username = '';
  var userImagePath;
  var processing = true;

  Future<Map<String, dynamic>> _uploadImage() async {
    String url = 'http://10.0.2.2:5000/facial_recognition';
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(url),
    );
    request.files.add(await http.MultipartFile.fromPath('file', userImagePath));
    print('ready to send request ...');
    var streamedResponse = await request.send();
    print('request is sent ...');
    var response = await http.Response.fromStream(streamedResponse);
    Map<String, dynamic> data = jsonDecode(response.body);
    return data;
  }

  void _getImageAndDetectFaces(String path, BuildContext context) async {
    final image = InputImage.fromFilePath(path);
    final FaceDetector faceDetector =
        GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      enableTracking: true,
      enableContours: true,
      enableClassification: true,
    ));

    List<Face> faces = await faceDetector.processImage(image);
    if (mounted) {
      if (faces.length > 0) {
        if (faces.length > 1) {
          setState(() {
            print("There is more than 1 face !");
          });
        } else {
          _cropAndSaveImage(path, faces[0]);
        }
      } else {
        setState(() {
          print("The image doesn't contain any face !");
        });
      }
    }
  }

  void _cropAndSaveImage(String path, Face face) {
    ImageLib.Image image = ImageLib.decodeImage(File(path).readAsBytesSync());
    print(
        "f ${face.boundingBox.topLeft.dy} ${face.boundingBox.topLeft.dx} ${face.boundingBox.width} ${face.boundingBox.height}");
    ImageLib.Image copy = ImageLib.copyRotate(
        ImageLib.copyCrop(
            image,
            face.boundingBox.topLeft.dy.toInt(),
            face.boundingBox.topLeft.dx.toInt(),
            face.boundingBox.width.toInt(),
            face.boundingBox.height.toInt()),
        -90);

    // Save the thumbnail as a PNG.
    File(path)..writeAsBytesSync(ImageLib.encodePng(copy));
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      cameraController = CameraController(cameras[1], ResolutionPreset.medium);
      cameraController.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: (cameraController != null)
          ? Column(
              children: [
                (userImagePath == null)
                    ? AspectRatio(
                        aspectRatio: cameraController.value.aspectRatio,
                        child: CameraPreview(cameraController),
                      )
                    : Image.file(File(userImagePath)),
                SizedBox(
                  height: 20,
                ),
                processing
                    ? FloatingActionButton(
                        child: Icon(
                          Icons.camera,
                          color: Colors.white,
                        ),
                        backgroundColor: Colors.black,
                        onPressed: () async {
                          try {
                            // Construct the path where the image should be saved using the path package.
                            DateTime now = DateTime.now();
                            String formattedDate =
                                DateFormat('yyyy_MM_dd_HH_mm_ss').format(now);
                            final path = join(
                              (await getTemporaryDirectory()).path,
                              '$formattedDate.png',
                            );
                            // Attempt to take a picture and log where it's been saved.
                            await cameraController.takePicture(path);
                            setState(() {
                              processing = false;
                            });
                            setState(() {
                              userImagePath = path;
                              print(path);
                            });
                            _getImageAndDetectFaces(path, context);
                            var res = await _uploadImage();
                            print('Res : $res');
                            setState(() {
                              if (res['response'] != null)
                                username = 'Hello ' +
                                    res['response'][0]['username'] +
                                    ' !';
                              else
                                username = 'aucun visage n\'est d??t??ct??';
                              print('Username : $username');
                            });
                          } catch (e) {
                            print(e);
                          }
                        })
                    : (username == '')
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          )
                        : Text(''),
                SizedBox(
                  height: 20,
                ),
                Text(username.toString()),
              ],
            )
          : Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue,
                ),
              ),
            ),
    );
  }
}
