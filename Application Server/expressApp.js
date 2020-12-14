
//use express module
var express = require("express");

//create an app
var app = express();

//set app port to listen to
app.set('port', process.env.PORT || 2468);
 
//set up middleware
app.use( express.static(__dirname + "/public") );

//-----------------------------------------------------

//use 'got' module for HTTP requests (to Node-Red)
const got = require('got');

/*functions using got() are found later in the code above their corresponding server calls*/


//------------------------------------------------------
//use mongoose module
const mongoose = require('mongoose');

//use file module (to read in images)
var fs = require('fs');

//connect to 'babyMonitorInfo' database (if not already there, will create new database)
mongoose.connect("mongodb://localhost:27017/babyMonitorInfo", {useNewUrlParser: true, useUnifiedTopology: true} );

//create new model called 'BMInfoRecords' with specified schema
const BMInfoRecords = mongoose.model('BMInfoRecord', {
    userID: String,
    selectedLullabyTrack: String,
    lullabyVolume: Number,
    playbackPaused: Boolean

    // alarmTimeSet: Date,
});

//--RECORD INSTANCE BELOW HAS BEEN CREATED ALREADY (only need executing once) 
//create new instance of BMInfoRecord
const user1ID = "user1";
// sampleLullabyTrack = {
//     "trackID":"2ezPqb8CcWlb8xEVYV9St2",
//     "trackURI":"spotify:track:2ezPqb8CcWlb8xEVYV9St2",
//     "trackName":"Forget Me Not",
//     "artistName":"Victor Kovacs",
//     "albumName":"Cotton Clouds"
// };
// lullabyString = JSON.stringify(sampleLullabyTrack);

// const bmInfo1 = new BMInfoRecord({
//     userID: user1ID,
//     selectedLullabyTrack: lullabyString,
//     lullabyVolume: 50,
//     playbackPaused: true
// });

// //save instances to 'babyMonitor' db and print object to console after completed
// bmInfo1.save().then( () => console.log("\nBMInfo1 Record saved to DB: ", bmInfo1, "\n") );

//------------------------------------------------------
//------------------------------------------------------

//respond to requests

//-----
app.get('/', function(req, res)
{
    console.log("GET request received for '/'.");
    returnContent = "<html> <body> <h3>Connected to Server successfully.</h3>";
    returnContent += " <p>Access <a href='http://localhost:2468/getAllLullabies'>http://localhost:2468/getAllLullabies</a> to get Lullaby Tracks from Spotify Playlist.</p>";
    returnContent += " </body></html>";
    res.send(returnContent);
});

//-----------------------------------------
/*getLullabiesList() - asynchronous function used to access node-red through HTTP GET request and return response*/
async function getLullabiesList(){
    try{
        const response = await got('http://localhost:1880/lullabiesList');
        return response.body;
    } catch(error){
        return error.response.body;
    }
}

/*getAllLullabies - Retrieves lullaby tracks' info through node-red from Spotify playlist*/
app.get('/getAllLullabies', function(req, res)  
{
    console.log("\n-------------------------\n");
    console.log("GET request received for '/getAllLullabies'.");
    
    //redirect this request to Node-Red "/lullabiesList" 
    //res.redirect("http://10.0.0.2:1880/lullabiesList");


    //request from Node-Red '/lullabiesList' to get list of track info
    getLullabiesList()
    .then(function(result){
        console.log("Sucess!\n", result);
        res.send(result);
    })
    .catch(function(result){
        console.log("Error!\n", result);
        res.send("Error");
    });
});


//-----------------------------------------
/*setNewLullaby() - asynchronous function used to access node-red through HTTP GET request and set spotify lullaby*/
async function setNewLullaby(newTrackURI){
    try{
        const response = await got("http://localhost:1880/setLullaby?trackURI=" + newTrackURI);
        return response.body;
    } catch(error){
        return error.response.body;
    }
}

/*setLullaby - (through Node-Red) sets Spotify track as new lullaby, as well as starting to play it and setting it to repeat */
app.get('/setLullaby', function(req, res)  
{
    console.log("\n-------------------------\n");
    console.log("GET request received for '/setLullaby'.");

    //get new lullaby track URI from query (e.g. "localhost:2468/setLullaby?trackURI=spotify:track:2sV9N58OhX1y1qH7au3W6Q")
    var newTrackURI = req.query.trackURI;   /*e.g. newTrackURI = "spotify:track:2sV9N58OhX1y1qH7au3W6Q"*/
    
    //redirect this request to Node-Red "/setLullaby" 
    //res.redirect("http://localhost:1880/setLullaby?trackURI=" + newTrackURI);    

    //request from Node-Red '/setLullaby' to get list of track info
    setNewLullaby(newTrackURI)
    .then(function(result){
        console.log("No exception!\n", result);
        
        res.send(result); //message of success/failure


        // //update database to store current lullaby selection
        resp = JSON.parse(result);
        var resultMsg = String(resp.result);
        if (resultMsg == "Success! Lullaby set, playing, and on repeat.") 
        {
            console.log("Update ('setLullaby') was successful. Now updating the database...");

            //retrieve rest of track information from request query
            newTrackSelected = {
                "trackURI": newTrackURI,
                "trackID": req.query.trackID,
                "trackName": req.query.trackName,
                "artistName": req.query.artistName,
                "albumName": req.query.albumName
            }

            newTrackDB = JSON.stringify(newTrackSelected);
            console.log("New Track:", newTrackDB);

            //execute update on DB to update value of 'selectedTrack' for the current record
            BMInfoRecords.updateOne({ userID: user1ID }, {selectedLullabyTrack: newTrackDB, playbackPaused: false }, function (err) {
                if (err) {
                    console.log("\nError reading/updating BMInfoRecords (for 'selectedTrack').\n");
                } else {
                    console.log("\n'selectedTrack' updated in DB successfully.\n");
                }
            });
        }
    })
    .catch(function(result){
        console.log("Error!\n", result);
        res.send(result);
    });
});


//-----------------------------------------
/*setNewVolume() - asynchronous function used to access node-red through HTTP GET request and set spotify lullaby volume*/
async function setNewVolume(newVolumeLevel){
    try{
        const response = await got("http://localhost:1880/setVolume?volumeLevel=" + newVolumeLevel);
        return response.body;
    } catch(error){
        return error.response.body;
    }
}

/*setVolume - (through Node-Red) sets new volume percent level for playback of Spotify tracks*/
app.get('/setVolume', function(req, res)  
{
    console.log("\n-------------------------\n");
    console.log("GET request received for '/setVolume'.");

    //get new volume level from query (e.g. "localhost:2468/setVolume?volumePercent=50")
    var newVolumeLevel = req.query.volumePercent;   /*e.g. newVolumeLevel = 50*/

    //redirect this request to Node-Red "/setVolume" 
    //res.redirect("http://localhost:1880/setVolume?volumeLevel=" + newVolumeLevel);   


    //request from Node-Red '/setVolume' to get list of track info
    setNewVolume(newVolumeLevel)
    .then(function(result){
        console.log("No exception!\n", result);
        res.send(result);  //message of success/failure

        //update database to store current lullaby volume level
        resp = JSON.parse(result);
        var resultMsg = String(resp.result);
        if (resultMsg == "Success! New Volume set.") 
        {
            console.log("Update ('setVolume') was successful. Now updating the database...");

            //execute update on DB to update value of 'lullabyVolume' for the current record
            var newVolumePercent = parseInt(newVolumeLevel);
            BMInfoRecords.updateOne({ userID: user1ID }, {lullabyVolume: newVolumePercent}, function (err) {
                if (err) {
                    console.log("\nError reading/updating BMInfoRecords (for 'lullabyVolume' value).\n");
                } else {
                    console.log("\n'LullabyVolume' value updated in DB successfully.\n");
                }
            });
        }
    })
    .catch(function(result){
        console.log("Error!\n", result);
        res.send(result);
    });
});

//-----------------------------------------
/*pauseSong() - asynchronous function used to access node-red through HTTP GET request and pause Spotify playback*/
async function pauseSong(){
    try{
        const response = await got("http://localhost:1880/pausePlayback");
        return response.body;
    } catch(error){
        return error.response.body;
    }
}

/*pauseLullaby - (through Node-Red) pauses the playback of Spotify tracks*/
app.get('/pauseLullaby', function(req, res)  
{
    console.log("\n-------------------------\n");
    console.log("GET request received for '/pauseLullaby'.");

    //redirect this request to Node-Red "/pausePlayback" 
    //res.redirect("http://http://localhost:1880/pausePlayback");

    //request from Node-Red '/pauseLullaby' to get list of track info
    pauseSong()
    .then(function(result){
        console.log("No exception!\n", result);
        res.send(result);  //message of success/failure

        //update database to store current lullaby playback status (now paused if this is successful)
        resp = JSON.parse(result);
        var resultMsg = String(resp.result);
        if (resultMsg == "Success! Playback Paused.") 
        {
            console.log("Update ('pauseLullaby') was successful. Now updating the database...");

            //execute update on DB to update value of 'playbackPaused' for the current record
            BMInfoRecords.updateOne({ userID: user1ID }, {playbackPaused: true }, function (err) {
                if (err) {
                    console.log("\nError reading/updating BMInfoRecords (for 'PlaybackPaused' status).\n");
                } else {
                    console.log("\n'PlaybackPaused' status updated in DB successfully.\n");
                }
            });
        }
    })
    .catch(function(result){
        console.log("Error!\n", result);
        res.send(result);
    });
});


//-----------------------------------------
/*getInfo - returns user info from database (to populate configuration app on initial load)*/
app.get('/getInfo', function(req, res)
{
    console.log("GET request received for '/getInfo'.");
    
    //retrieve userID from query
    searchUserID = req.query.userID;

    //retrive BMInfo record from DB
    BMInfoRecords.find( {userID: searchUserID}, function (err, doc) {
        //if error, return
        if (err) {
            console.log(err);
            res.send(err);
        }
        else
        {
            console.log("\nRetrieving BMInfo Record - DB Query Result: ", doc);   //doc contains one element only (name assumed to be unique)

            //"find(userID)" here should always return a valid doc (of length 1)
            
            //return record (data with set content type for response)
            responseRecord = {
                selectedTrack: JSON.parse(doc[0].selectedLullabyTrack),
                lullabyVolume: doc[0].lullabyVolume,
                playbackPaused: doc[0].playbackPaused
            }
            console.log("Response Sent: ", responseRecord);

            res.send( responseRecord );
        }  
    });

});


//------------------------------------------------------
/*takeSnapshot() - asynchronous function used to access node-red through HTTP GET request and take snapshot of child*/
async function takeSnapshot(){
    try{
        const response = await got("http://localhost:1880/checkInSnapshot");
        return response.body;
    } catch(error){
        return error.response.body;
    }
}

/*checkInOnChild - returns a snapshot of the child taken from a live camera now (through node-red)*/
app.get('/checkInOnChild', function(req,res)
{
    console.log("GET request received for '/checkInOnChild'.");

    //request from Node-Red '/checkInOnChild' to get a snapshot of the child from the live camera
    takeSnapshot()
    .then(function(result){
        console.log("No exception!\n");
        res.send(result);  //payload contains image in base64 encoding as JSON {"snapshot" : "..imageStr.."}

        // console.log(result);
        
    })
    .catch(function(result){
        console.log("Error!\n", result);
        res.send(result);
    });
});


//------------------------------------------------------
//------------------------------------------------------

//launch the server
app.listen( app.get('port'), function() {
    console.log("\nExpress started on http://localhost:" + app.get('port') + "; press Ctrl-C to terminate.\n");
} )
