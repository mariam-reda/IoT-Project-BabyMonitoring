// This sample shows creation of a [Card] widget that shows album information
// and two actions.

import 'dart:convert';
import 'dart:typed_data';

import 'package:baby_monitoring/lullabyTrack.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'mqtt.dart';

import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
//MQTT Class code -- [code in mqtt.dart file]

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

void main() => runApp(MyApp());

/// This is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Baby Monitoring System';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      home: Scaffold(
        appBar: AppBar(
          title: Center(child: const Text(_title)),
          backgroundColor: Colors.lightBlueAccent,
        ),
        body: MyStatefulWidget(),
      ),
    );
  }
}

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

/// This is the stateless widget that the main application instantiates.
class MyStatefulWidget extends StatefulWidget {
  MyStatefulWidget({Key key}) : super(key: key);

  @override
  _MyStatefulWidgetState createState() => _MyStatefulWidgetState();
}

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  static const String userID = "user1";

  //--------------------------------------
  //LULLABY SONG SELECTION VARIABLES AND METHODS
  LullabyTrack chosenLullabyTrack; /*will contain full track info once a track is selected*/
  String currentLullabyText = "[No lullaby set]";
  TextEditingController _lullabySongController = TextEditingController(
    text: "Set Lullaby",
  );

  //----------
  //method used to navigate to 'Select Lullaby' Screen and wait [asynchronously] for data to be sent back (to set new lullaby/display new selected lullaby)
  void  _awaitReturnValueFromLullabyScreen(BuildContext context) async {
    // start the second screen ('SelectLullaby') and wait for it to finish with a result
    final lullabySelectionResults = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LullabyWidget(chosenLullabyTrack)));
    /*lullabySelectionResults = [resultsMessage, lullabySelected]*/

    if (lullabySelectionResults == null)  /*if null, then user went to page and returned without clicking, so do not continue executing function*/
      return;

    // after the 'Select Lullaby' result comes back, update the UI accordingly
    String updateStatusMsg = "";
    Color toastColor;
    if (lullabySelectionResults[0].contains("Success")) //resultsMessage indicates successful update
    {
      updateStatusMsg = "Lullaby choice has been updated! Lullaby is now playing from Spotify in the baby's room";
      toastColor = Colors.blue[300];
    }
    else
    {
      updateStatusMsg = lullabySelectionResults[0]; //display error message as is (already set)
      toastColor = Colors.orange[300];
    }

    //display toast message to indicate update status
    Fluttertoast.showToast(
      msg: updateStatusMsg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 30,
      backgroundColor: toastColor,
      fontSize: 16,
    );

    if (lullabySelectionResults[1] != null && lullabySelectionResults[0].contains("Success")) /*check if new lullaby has been set*/
    {
      setState(() {
        //update the text beside the 'Current lullaby selected: ' label to the new lullaby title
        currentLullabyText = "'" + lullabySelectionResults[1].trackName + "'";
        chosenLullabyTrack = lullabySelectionResults[1];
        print("New Lullaby Text set in Main: " + currentLullabyText);

        //update the 'isLullabyPlaying' variable (since setting a lullaby automatically starts playing it, so playback is now not paused)
        isLullabyPlaying = true;
      });
    }
  }

  //--------------------------------------
  //LULLABY VOLUME VARIABLES AND METHODS
  double _currentSliderValueVolume = 50;  /*slider volume - not yet set (not sent back to server yet - just movement of slider)*/
  String currentSetVolumeText = "50";   /*officially set volume percent on Spotify*/
  TextEditingController _lullabyVolumeController = TextEditingController(
    text: "Set Volume",
  );

  //----------
  //setNewVolumeLevel() - takes the current volume level from slider and sends it to server to update Spotify volume
  void _setNewVolumeLevel(BuildContext context) async {
    print("Called setNewVolumeLevel().");

    //display message to user to indicate that the lullaby selected is being updated (since it takes some time)
    Fluttertoast.showToast(
      msg: "Updating lullaby volume...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 10,
      backgroundColor: Colors.grey,
      fontSize: 16,
    );

    //update volume on spotify through server (going through to node-red)
    String newVolume = _currentSliderValueVolume.toStringAsFixed(0);
    http.Response _get = await http.get("http://10.0.2.2:2468/setVolume?volumePercent=" + newVolume);

    //decode json response
    var _get_result = jsonDecode(_get.body);
    print("_get_result: " + _get_result.toString());

    //create list from decoded json
    String resultsMessage = _get_result['result'] as String;
    print("ResultsList: " + resultsMessage);

    // after the 'Set Volume' result comes back, display Toast to user to indicate volume update status and update the UI accordingly
     //display toast message to indicate update status
    Fluttertoast.showToast(
      msg: resultsMessage,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 30,
      backgroundColor: (resultsMessage.contains("Success") ? Colors.blue[300] : Colors.orange[300]),  /*background is blue or orange depending on success/failure of update*/
      fontSize: 16,
    );

    //update UI to indicate new volume level
    setState(() {
      if (resultsMessage.contains("Success")) //update was successful -> update 'current volume' displayed
      {
          currentSetVolumeText = newVolume;
      }
      else  //update was unsuccessful -> reset slider back to (previous) set volume level
      {
        _currentSliderValueVolume =  double.parse(currentSetVolumeText);
      }
    });
  }

  //--------------------------------------
  //LULLABY PLAYBACK (PAUSE) VARIABLES AND METHODS
  bool isLullabyPlaying = false;   /*false = 'Paused', true = 'Playing' */
  TextEditingController _lullabyPlaybackController = TextEditingController(
    text: "Pause Playback",
  );

  //----------
  //pauseLullabyPlayback() - uses HTTP request to server to pause the Spotify playback (through node-red API)
  void _pauseLullabyPlayback(BuildContext context) async {
    print("Called pauseLullabyPlayback().");

    //display message to user to indicate that playback is being paused (since it takes some time)
    Fluttertoast.showToast(
      msg: "Pausing playback...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 10,
      backgroundColor: Colors.grey,
      fontSize: 16,
    );

    //update volume on spotify through server (going through to node-red)
    http.Response _get = await http.get("http://10.0.2.2:2468/pauseLullaby");

    //decode json response
    var _get_result = jsonDecode(_get.body);
    print("_get_result: " + _get_result.toString());

    //create list from decoded json
    String resultsMessage = _get_result['result'] as String;
    print("ResultsList: " + resultsMessage);

    // after the 'Pause Playback' result comes back, display Toast to user to indicate volume update status and update the UI accordingly
    //display toast message to indicate update status
    Fluttertoast.showToast(
      msg: resultsMessage,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 30,
      backgroundColor: (!resultsMessage.contains("Error") ? Colors.blue[300] : Colors.orange[300]),  /*background is blue or orange depending on success/failure of update*/
      fontSize: 16,
    );

    //update UI to indicate new volume level
    setState(() {
      if (resultsMessage.contains("Success")) //update was successful -> update 'current playback status' displayed
      {
        isLullabyPlaying = false;
      }
      //else, keep same as before
    });

  }

  //--------------------------------------
  //CHECK IN ON CHILD (TAKE SNAPSHOT) VARIABLES AND METHODS

  //getSnapshotOfChild() - requests from server to get snapshot image of child from 'live' camera
  void _getSnapshotOfChild(BuildContext context) async {
    print("Called getShapshotOfChild().");

    //display message to user to indicate that the snapshot is being taken (since it takes some time to get sent back)
    Fluttertoast.showToast(
      msg: "Checking in now and taking snapshot...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey,
      fontSize: 16,
    );

    //request to get the snapshot image through server (going through to node-red to access live camera)
    http.Response _get = await http.get("http://10.0.2.2:2468/checkInOnChild");

    //decode json response
    var _get_result = jsonDecode(_get.body);
    print("_get_result: " + _get_result.toString());

    //create list from decoded json
    String imageBase64 = _get_result['snapshot'] as String;
    print("imageBase64: " + imageBase64);

    //check if 'snapshot' is empty (i.e. error in connecting to live camera)
    if (imageBase64.isEmpty)
    {
      //display message to inform the user of the error and return
      Fluttertoast.showToast(
        msg: "Error connecting to the live camera",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 30,
        backgroundColor:Colors.orange[300],  /*background is orange to indicate failure*/
        fontSize: 16,
      );

      return;
    }
    //otherwise, continue with the below code

    Fluttertoast.showToast(
      msg: "New snapshot available!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 5,
      backgroundColor: Colors.blue[300],
      fontSize: 16,
    );

    //decode image from base64 to display it
    Uint8List imageDecoded = base64Decode(imageBase64);

    //send decoded image to 'showDialog' function to display the image in a dialog box on the page
    showSnapshotDialogBox(context, Image.memory(imageDecoded).image, "Check In", "Here is a snapshot of your child right now:");

  }

  //----------
  //showSnapshotDialogBox() - creates a dialog box to display the snapshot image in for checking in on child
  showSnapshotDialogBox(context, decodedImage, title, desc)
  {
    return showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              padding: EdgeInsets.all(8),
              height: MediaQuery.of(context).size.width / 1.4,
              width: MediaQuery.of(context).size.width / 1.2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(fontSize: 25, color: Colors.green, fontWeight: FontWeight.bold,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      desc,
                      maxLines: 3,
                      style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.green[800]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Image(
                    image: decodedImage,
                    width: (MediaQuery.of(context).size.width / 1.2) * 0.7,
                    height: (MediaQuery.of(context).size.width / 1.2) * 0.52,
                  ),
                ]
              ),
            ),
          ),
        );
      },
    );
  } //end of showSnapshotDialogBox() method


  //--------------------------------------
  //ALARM TIME VARIABLES
  String currentAlarmTimeText = "[No alarm set]"; /*text to display current alarm time set*/
  TimeOfDay selectedTime = TimeOfDay(hour: 00, minute: 00);
  TextEditingController _timeController = TextEditingController(
    text: "Set Alarm Time",
  );

  //----------
  //selectTime() - used to display timePicker and set the selected alarm time
  Future<void> _selectTime(BuildContext context) async {
    /*create and display timePicker and define the returned 'pickedTime' value accordingly*/
    final TimeOfDay pickedTime = await showTimePicker(
        context: context,
        initialTime: selectedTime,
        helpText: "Select the new alarm time",
        builder: (BuildContext context, Widget child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child,
          );
        });
    if (pickedTime != null && pickedTime != selectedTime) /*check if new time has been set*/
      setState(() {
        selectedTime = pickedTime;
        print("New Alarm time has been selected: $selectedTime");
        currentAlarmTimeText = selectedTime.format(context);

        /*no backend support created yet - this is just a demo for the potential expansion of the project*/
      });
  }

  //--------------------------------------
  //--------------------------------------
  //MQTT VARIABLES AND METHODS
  MQTTClient cl;

  //----------
  //setUpMQTT() - creates an MQTT client instance and connects and subscribes to desired topics
  void setUpMQTT() async {
    // create an MQTT client.
    cl = new MQTTClient('10.0.2.2', '1883', _onMQTTMessageReceived);  /*includes our custom onMessage function*/

    //connect to MQTT
    await cl.connect();

    //subscribe to required topics
    cl.subscribe("Project/distress", null); /*topic used to publish when child's expression is detected to be distress (angry/sad/fearful/disgusted)*/
    cl.subscribe("Audio/DecibelLevel", null); /*topic used to publish when noise in child's room is above a set level (80dB) to inform parent to check in*/
  }

  //----------
  //onMQTTMessageReceived() - custom onMessage function for MQTT to respond to MQTT messages based on topic
  void _onMQTTMessageReceived(String topic, String payload)
  {
    /*Two potential messages could be received - Distress (expression detected) or DecibelLevel (loud audio detected)*/

    if (topic == "Project/distress")  /*received message that child expression was distressed (sad/angry/disgusted/fearful)*/
    {
      print("MQTT - DISTRESSED message received. Payload: " + payload.toString());

      //parse the detected expression from the payload
      var decodedPayload = jsonDecode(payload);
      String childExpression = decodedPayload["expressionDetected"] as String;
      print("Expression detected: " + childExpression);

      //create message to display in dialog box
      String message = "Your child's expression appears to be distressed (sad/angry/disgusted/fearful).";
      String specificExpression = "Detected Expression:  " + childExpression.toUpperCase();

      //display alert dialog box
      showMQTTAlertDialogBox(context, "Distress detected", message, specificExpression);  /*expression detected is sent as extra message with this alert*/
    }

    else if (topic == "Audio/DecibelLevel") /*received message for decibel level reading being high (loud noises in child's room -> might be crying)*/
    {
      //create message to display in dialog box
      String message = "There seems to be some loud noises in the child's room.";

      //display alert dialog box
      showMQTTAlertDialogBox(context, "Loud Noises detected", message, "");  /*no extra message is sent with this alert*/
    }
  }

  //----------
  //showMQTTAlertDialogBox() - dialog box displays to notify guardian of untimed issue (based on notification received from MQTT)
  showMQTTAlertDialogBox(context, title, description, extraInfo)
  {
    return showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              padding: EdgeInsets.all(8),
              height: MediaQuery.of(context).size.width / 1.4,
              width: MediaQuery.of(context).size.width / 1.2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Text(
                        title,
                        style: TextStyle(fontSize: 27, color: Colors.red[400], fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 15),
                      child: Text(
                        description,
                        style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.red[900],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 30),
                      child: Text(
                        "You may want to check in on your child.",
                        style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        extraInfo,
                        style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: Colors.red[900],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  ]
              ),
            ),
          ),
        );
      },
    );
  }

  //--------------------------------------
  //--------------------------------------

  //initState() - initializes the statefulWidget
  void initState() {
    super.initState();

    // initialize MQTT
    setUpMQTT();

    //set up the app based on last user information saved on server
    print("Calling setUpAppInfo()...");
    setUpAppInfo();
  }

  //----------
  //setUpAppInfo - retrieves info from DB to display last selected settings
  void setUpAppInfo() async {
    print("Called setUpAppInfo().");

    //fetch record from the server (from database)
    http.Response _get;
    try {
      _get = await http.get("http://10.0.2.2:2468/getInfo?userID=" + userID);
    }
    catch (error)
    {
      print("Error on GET for Info: " + error.message + "\n");
      return;
    }

    print("Status Code: " + _get.statusCode.toString());

    //check if it was successful
    if (_get == null || _get.statusCode != 200) {
      print("--could not get info.");
      return;
    }

    //decode json response
    var _get_result = jsonDecode(_get.body);
    print("_get_result: " + _get_result.toString());

    //update UI with retrieved information
    setState(() {
      //set 'chosenLullabyTrack' object from decodedJSON
      var fullSelectedTrackInfo = _get_result["selectedTrack"];
      chosenLullabyTrack = new LullabyTrack(fullSelectedTrackInfo["trackID"], fullSelectedTrackInfo["trackURI"],
          fullSelectedTrackInfo["trackName"], fullSelectedTrackInfo["artistName"], fullSelectedTrackInfo["albumName"]);

      //set 'currentLullabyText' (indicates current lullaby track selected)
      currentLullabyText = fullSelectedTrackInfo["trackName"];

      //set current lullaby volume
      _currentSliderValueVolume = _get_result["lullabyVolume"].truncateToDouble();
      currentSetVolumeText = _currentSliderValueVolume.toStringAsFixed(0);

      //set 'pause playback' status (indicates if playback is playing to enable/disable the pause feature)
      isLullabyPlaying = !_get_result["playbackPaused"];  /*'NOT' of result since DB stores paused=true but variable uses paused=false*/

    });
  }

  //--------------------------------------
  //--------------------------------------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Image(
              image: NetworkImage(
                  "https://www.babycentre.co.uk/ims/2012/10/stk_babyspath_BPH061_wide.jpg"),
          ),

          //------------------------------------------
          Divider(
            thickness: 5,
            indent: 20,
            endIndent: 20,
            color: Colors.blueGrey,
            height: 25,
          ),

          //------------------------------------------
          Center(
            child: Column(
              children: [

                //---------------------------------------
                //CARD FOR SETTING A LULLABY (SONG SELECTION)
                Card(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Icon(Icons.music_note_outlined, color: Colors.pink,),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                              child: Text(
                                "Lullaby Song",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 40),
                            child:
                              Column(
                              children: <Widget>[
                                Text("Current lullaby selected:  ",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(currentLullabyText,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width / 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () { /*on Tap, move to the 'Select Lullaby' Screen*/
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute(builder: (context) => LullabyWidget()),
                                      // );
                                      _awaitReturnValueFromLullabyScreen(context);  /*method created to push with Navigator to new screen, then wait for response to set lullaby*/
                                    },
                                    child: Container(
                                      // margin: EdgeInsets.only(top: 30),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                      ),
                                      child: TextFormField(
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        // onSaved: (String val) {},
                                        enabled: false,
                                        controller: _lullabySongController,
                                        decoration: InputDecoration(
                                          disabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide.none),
                                          // contentPadding: EdgeInsets.all(5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                //------------------------------------------
                //CARD FOR SETTING THE LULLABY VOLUME
                Card(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Icon(Icons.surround_sound_outlined, color: Colors.pinkAccent,),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                              child: Text(
                                "Lullaby Volume",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 40),
                            child:
                            Row(
                              children: <Widget>[
                                Text("Current lullaby volume set:  ",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontSize: 15,
                                  ),
                                ),
                                Container(
                                  width: MediaQuery.of(context).size.width / 2.5, /*to trigger text wrapping within container*/
                                  child: Text(currentSetVolumeText,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Column(
                            children: [
                              Text("Set a new volume level:  ", style: TextStyle(color: Colors.lightGreen[900]),),
                            ],
                          ),
                          Column(
                            children: [
                              Text(_currentSliderValueVolume.toStringAsFixed(0), style: TextStyle(color: Colors.lightGreen[900], fontWeight: FontWeight.bold,),), /*no decimal places included*/
                            ],
                          ),
                          Column(
                            children: [
                              Slider(
                                min: 0,
                                max: 100,
                                value: _currentSliderValueVolume,
                                activeColor: Colors.lightGreen[700],
                                onChanged: (double value) {   /*for moving the slider only (not the same as setting the volume officially)*/
                                  setState(() {
                                    _currentSliderValueVolume = value.truncateToDouble(); /*no decimal places included*/
                                    print("Lullaby Volume: " + _currentSliderValueVolume.toString());
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width / 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _setNewVolumeLevel(context);
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                      ),
                                      child: TextFormField(
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        // onSaved: (String val) {},
                                        enabled: false,
                                        controller: _lullabyVolumeController,
                                        decoration: InputDecoration(
                                          disabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                //------------------------------------------
                //CARD FOR PAUSING THE LULLABY PLAYBACK
                Card(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Icon(Icons.pause_circle_outline, color: Colors.pinkAccent,),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                              child: Text(
                                "Pause Lullaby Playback",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 40),
                            child:
                            Row(
                              children: <Widget>[
                                Text("Current lullaby playback status:  ",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontSize: 15,
                                  ),
                                ),
                                Text((isLullabyPlaying ? "Playing" : "Paused"),
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width / 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (isLullabyPlaying) /*true -> lullaby is currently playing and can be paused*/
                                        _pauseLullabyPlayback(context);
                                      else /*false -> lullaby is currently playing and cannot be paused*/
                                      {
                                        //display notification informing the user that they cannot pause now
                                        Fluttertoast.showToast(
                                          msg: "Disabled - Cannot pause when nothing is playing",
                                          toastLength: Toast.LENGTH_SHORT,
                                          gravity: ToastGravity.BOTTOM,
                                          timeInSecForIosWeb: 10,
                                          backgroundColor: Colors.grey,
                                          fontSize: 16,
                                        );
                                      }
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: (isLullabyPlaying ? Colors.blue : Colors.grey), /*blue if playing (enabled), grey if paused (disabled)*/
                                      ),
                                      child: TextFormField(
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        // onSaved: (String val) {},
                                        enabled: false,
                                        controller: _lullabyPlaybackController,
                                        decoration: InputDecoration(
                                          disabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                //------------------------------------------

                Divider(
                  thickness: 5,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.blueGrey,
                  height: 25,
                ),

                //------------------------------------------
                //CARD FOR CHECKING IN ON CHILD (TAKE SNAPSHOT)
                Card(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Icon(Icons.remove_red_eye_outlined, color: Colors.lightGreen,),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                              child: Text(
                                "Check In on Child",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 40),
                            child:
                            Row(
                              children: <Widget>[
                                Container(
                                  width: MediaQuery.of(context).size.width / 1.25, /*to trigger text wrapping within container*/
                                  child: Text("Press the button to check in on your child and see a snapshot of what the room looks like right now",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blueGrey,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: FlatButton(
                          child: Text(
                            'Check In Now',
                            style: TextStyle(fontSize: 18),
                          ),
                          color: Colors.green,
                          textColor: Colors.white,
                          padding: EdgeInsets.all(12.0),
                          onPressed: () {
                            // Request to take a snapshot from the live camera and display it once received
                            _getSnapshotOfChild(context);
                          },
                        ),
                      )
                    ],
                  ),
                ),

                //------------------------------------------

                Divider(
                  thickness: 5,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.blueGrey,
                  height: 25,
                ),

                //------------------------------------------
                //CARD FOR ALARM TIME
                Card(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Icon(Icons.timelapse, color: Colors.lightBlue,),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 0, 3),
                              child: Text(
                                "Alarm Time",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 40),
                            child: Row(
                              children: <Widget>[
                                Text("Current alarm time set:  ",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(currentAlarmTimeText,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            width: MediaQuery.of(context).size.width / 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _selectTime(context); /*display timePicker to select new time*/
                                    },
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                      ),
                                      child: TextFormField(
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        // onSaved: (String val) {
                                        //   _setTime = val;
                                        //   print("onSaved: SetTime = $_setTime");
                                        // },
                                        enabled: false,
                                        controller: _timeController,
                                        decoration: InputDecoration(
                                          disabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide.none),
                                          // labelText: 'Time',
                                          // contentPadding: EdgeInsets.all(5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ],
                //),
                //),

                //------------------------------------------

                Divider(
                  thickness: 5,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.blueGrey,
                  height: 25,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
//second page widget
class LullabyWidget extends StatefulWidget {
  final LullabyTrack previousLullaby;

  LullabyWidget(this.previousLullaby, {Key key}) : super(key: key); /*previous lullaby name is passed on activity creation*/

  @override
  _SelectLullabyState createState() => _SelectLullabyState();
}

//---------------------------------------------------
//second page state
class _SelectLullabyState extends State<LullabyWidget> {
  static const String _lullabyPageTitle = 'Select a Lullaby';

  //class variables
  List<LullabyTrack> lullabiesList;
  LullabyTrack _selectedLullaby = new LullabyTrack.emptyConstructor();

  List<Widget> lullabyWidgets = [];   /*the list of widgets that are used to display the lullaby tracks radio list*/

  String hiddenUpdateMessage = "";

  //-------------
  //setSelectedLullaby() - sets a lullaby list item as selected and updated the UI
  setNewSelectedLullaby(LullabyTrack aLullaby) {
    setState(() {
      _selectedLullaby = aLullaby;
      print("New selectedLullaby: " + _selectedLullaby.trackName);

      //update list to show selected lullaby
      createRadioListLullabies();
    });
  }

  //--------------
  //getTracksFromServer() - uses HTTP GET request to retrieve all lullabies in Spotify playlist from server (then from node-red)
  void getTracksFromServer() async {
    print("CALLED getTracksFromServer()");
    http.Response _get = await http.get("http://10.0.2.2:2468/getAllLullabies");



    //create list from decoded json
    List resultsList;
    try {
      //decode json response
      var _get_result = jsonDecode(_get.body);

      resultsList = _get_result['lullabyTracks'] as List;
      print("ResultsList: " + resultsList.toString());
    }
    catch (error)
    {
      //display toast to inform user of error
      Fluttertoast.showToast(
        msg: "Error - Cannot get the lullabies list at this time. \nTry again later.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 30,
        backgroundColor: Colors.orange[300],
        fontSize: 16,
      );
      return;
    }

    //define lullabiesList
    lullabiesList = new List<LullabyTrack>();

    //populate list with parsed response items
    for (int i = 0; i < resultsList.length; i++) {
      lullabiesList.add(new LullabyTrack(
          resultsList[i]['trackID'], resultsList[i]['trackURI'],
          resultsList[i]['trackName'], resultsList[i]['artistName'],
          resultsList[i]['albumName']));
    }

    //create the radio list for the lullaby tracks and update the UI
    createRadioListLullabies();
  }

  //--------------
  //createRadioListLullabies() - dynamically creates the RadioListTile widgets for each lullaby track
  void createRadioListLullabies()   /*-returns/sets List<Widget> lullabyWidgets to display tracks*/
  {
    //create widgets list
    List<Widget> lullabyWidgets_temp = [];
      for (LullabyTrack aLullaby in lullabiesList) {
        lullabyWidgets_temp.add(
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: RadioListTile(
              value: aLullaby,
              groupValue: _selectedLullaby,
              title: Text(aLullaby.trackName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17.5,),),
              subtitle: Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 5),
                  child: Column(
                      children: [
                        Text(aLullaby.artistName, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500)),
                        Text(aLullaby.albumName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, fontStyle: FontStyle.italic)),
                      ],
                  ),
              ),
              onChanged: (lullabyClicked) {
                print("Lullaby Clicked: " + lullabyClicked.trackName);  /*executes for the current track*/
                setNewSelectedLullaby(lullabyClicked);
              },
              selected: _selectedLullaby == aLullaby, /*color of radio item text is set dependent on if it is selected*/
              activeColor: Colors.pink,
            ),
          ),
        );
      }
      print("Radio List setup complete.");

    //update UI with list
    setState(() {
      lullabyWidgets = lullabyWidgets_temp;
    });
  }

  //----------------
  //updateServerWithNewLullaby() - uses HTTP GET request to set lullaby, update Spotify queue, and start playing the lullaby from server (then through node-red)
  void updateServerWithNewLullaby() async {
      print("CALLED updateServerWithNewLullaby()");

      //display message to user to indicate that the lullaby selected is being updated (since it takes some time)
      Fluttertoast.showToast(
        msg: "Updating lullaby selection...",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 30,
        backgroundColor: Colors.grey,
        fontSize: 16,
      );

      // http.Response _get = await http.get("http://10.0.2.2:2468/setLullaby?trackURI=" + _selectedLullaby.trackURI);
      http.Response _get = await http.get("http://10.0.2.2:2468/setLullaby?trackURI=" + _selectedLullaby.trackURI
          + "&trackID=" + _selectedLullaby.trackID + "&trackName=" + _selectedLullaby.trackName
          + "&artistName=" + _selectedLullaby.artistName + "&albumName=" + _selectedLullaby.albumName);


      //decode json response
      var _get_result = jsonDecode(_get.body);
      print("_get_result: " + _get_result.toString());

      //create list from decoded json
      String resultsMessage = _get_result['result'] as String;
      print("ResultsList: " + resultsMessage);

      //send confirmed lullaby data back to the first screen and pop this activity to redirect back there
      _sendDataBack(context, resultsMessage);
  }

  //-----------------
  // get the selected lullaby radio button and send it back to the FirstScreen
  void _sendDataBack(BuildContext context, String resultsMessage) {
    LullabyTrack trackToSendBack = _selectedLullaby;
    print("Sending Back: Track: " + _selectedLullaby.trackName + " Results Msg: " + resultsMessage);

    var sendBack = [resultsMessage, trackToSendBack];
    Navigator.pop(context, sendBack);
  }


  //-----------------
  @override
  void initState() {
    super.initState();

    //set the initially selected lullaby (the last selected lullaby - passed from first activity)
    if (widget.previousLullaby != null) /*only set selectedLullaby if this is not null*/
    {
      print("Widget Previous Lullaby = " + widget.previousLullaby.trackName);
      //setSelectedLullaby(widget.previousLullaby);
      _selectedLullaby = widget.previousLullaby; /*sets variable selectedLullaby to the passed lullaby*/
    }
    //otherwise, selectedLullaby will be null to start, and radio group will not have any selected tracks to start

    //get the lullaby tracks list
    getTracksFromServer();
  }


  //-----------------
  @override
  Widget build (BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Center(child: const Text(_lullabyPageTitle)),
          backgroundColor: Colors.lightBlueAccent,
        ),

        body:
        SingleChildScrollView(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(top:20, left: 20, right: 20),
                  child: Text("LULLABIES AVAILABLE", style: TextStyle(fontSize: 15,),),
                ),
                Container(
                  alignment: Alignment.topLeft,
                  width: MediaQuery.of(context).size.width / 1.05,  /*to trigger text wrapping within container*/
                  padding: EdgeInsets.all(20.0),
                  child: Text("Choose a lullaby and click the *'Confirm Lullaby Selection'* button below the list to set the track as your new lullaby",
                    style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w400, color: Colors.indigo,),),
                ),
                Column(
                children: lullabyWidgets, /*create the widgets dynamically through the function*/
              ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RaisedButton(
                        child: Text("Confirm Lullaby Selection", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,),),
                        color: Colors.green,
                        textColor: Colors.white,
                        padding: EdgeInsets.all(10.0),
                        onPressed: () {
                          updateServerWithNewLullaby(); /*send new selected lullaby back to server to update records + set lullaby and play it*/
                         // _sendDataBack(context); /*send back confirmed lullaby to the main activity and pop current activity*/
                        },
                      ),

                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.topLeft,
                  width: MediaQuery.of(context).size.width / 1.05,  /*to trigger text wrapping within container*/
                  padding: EdgeInsets.only(left: 20.0, right: 20, bottom: 20),
                  child: Text("Please only click on the Confirm button *ONCE*, then *WAIT* until you are redirected back to the Home Screen",
                    style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: Colors.red,),),
                ),
            ],
          ),
        ),
    );
  }

}