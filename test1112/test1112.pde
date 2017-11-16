//  serial connection ref:
//  http://coopermaa2nd.blogspot.tw/2011/03/processing-arduino.html

import processing.serial.*;
import ddf.minim.*;
import ddf.minim.ugens.*;

Serial myPort;
int switchValue;
boolean recordButtonSTATE;

Minim minim;

FilePlayer player;
FilePlayer player2;

// for recording
AudioInput in;
AudioRecorder recorder;
boolean recorded;

// for playing back
AudioOutput out;
FilePlayer player3;

String audioLayer1 = "groove.mp3";
String audioLayer2 = "NTUST_Sounds.mp3";

int recordCount = 0;

void setup()
{
  size(512, 200, P3D);
  
  // we pass this to Minim so that it can load files from the data directory
  minim = new Minim(this);
  
  // use the getLineIn method of the Minim object to get an AudioInput
  in = minim.getLineIn(Minim.STEREO); // use the getLineIn method of the Minim object to get an AudioInput
  
  
  // loadFile will look in all the same places as loadImage does.
  // this means you can find files that are in the data folder and the 
  // sketch folder. you can also pass an absolute path, or a URL.
  player = new FilePlayer( minim.loadFileStream( audioLayer1 ));
  player2 = new FilePlayer( minim.loadFileStream( audioLayer2 ));

  recorder = minim.createRecorder(in, "test-recording" + recordCount + ".wav");

  out = minim.getLineOut( Minim.STEREO );

  player.patch(out);
  player2.patch(out);

  textFont(createFont("Arial", 12));

  String portName = Serial.list()[1];
  myPort = new Serial(this, portName, 115200);

}

void draw()
{
  background(0);
  stroke(255);
  
  // draw the waveforms so we can see what we are monitoring
  for(int i = 0; i < in.bufferSize() - 1; i++)
  {
    line( i, 50 + in.left.get(i)*50, i+1, 50 + in.left.get(i+1)*50 );
    line( i, 150 + in.right.get(i)*50, i+1, 150 + in.right.get(i+1)*50 );
  }
  
  String monitoringState = in.isMonitoring() ? "enabled" : "disabled";
  text( "Input monitoring is currently " + monitoringState + ".", 5, 15 );



  //show text if it's recording
  if ( recorder.isRecording() )
  {
    text("Now recording, press the r key to stop recording.", 5, 40);
  }
  else if ( !recorded )
  {
    text("Press the r key to start recording.", 5, 40);
  }
  else
  {
    text("Press the s key to save the recording to disk and play it back in the sketch.", 5, 40);
  }  

  getSTATE();
  getButtonValue();
  //loadSoundFile();


}

void keyPressed()
{
  switch(key){
    case 'm':
      if ( in.isMonitoring() ){
        in.disableMonitoring();
      }
      else{
        in.enableMonitoring();
      }
      break;
      
    case 'M':
      if ( in.isMonitoring() ){
        in.disableMonitoring();
      }
      else{
        in.enableMonitoring();
      }
      break;
    case '1':
      println("audioLayer1 = " + audioLayer1);

      if ( player.isPlaying() )
      {
        player.pause();
      }
  // if the player is at the end of the file,
  // we have to rewind it before telling it to play again
      else if ( player.position() == player.length() )
      {
        player.rewind();
        player.play();
      }
      else
      {
        player.play();
      }
      break;
      
    case '2':
      println("audioLayer2 = " + audioLayer2);

      if ( player2.isPlaying() )
      {
        player2.pause();
      }
      // if the player is at the end of the file,
      // we have to rewind it before telling it to play again
      else if ( player2.position() == player.length() )
      {
        player2.rewind();
        player2.play();
      }
      else
      {
        player2.play();
      }
      break;
  }
}
  

void keyReleased()
{
  //if ( !recorded && key == 'r' ) 
  switch(key){
    // to indicate that you want to start or stop capturing audio data, 
    // you must callstartRecording() and stopRecording() on the AudioRecorder object. 
    // You can start and stop as many times as you like, the audio data will 
    // be appended to the end of to the end of the file. 
    case 'r':
      if ( recorder.isRecording() ) 
      {
        recorder.endRecord();
        recorded = true;
      }
      else 
      {
      recorder.beginRecord();
      }
      break;

    case 's':
      // we've filled the file out buffer, 
      // now write it to a file of the type we specified in setup
      // in the case of buffered recording, 
      // this will appear to freeze the sketch for sometime, if the buffer is large
      // in the case of streamed recording, 
      // it will not freeze as the data is already in the file and all that is being done
      // is closing the file.
      // save returns the recorded audio in an AudioRecordingStream, 
      // which we can then play with a FilePlayer
      if ( player3 != null )
      {
        player3.unpatch( out );
        player3.close();
      }
      player3 = new FilePlayer( recorder.save() );
      player3.patch( out );
      player3.play();

      //player.close();
      //player2.close();


      //shift audioLayer1 to audioLayer2
        //player2 = player;
      audioLayer2 = audioLayer1;
      player2.unpatch(out);
      player2.close();
      player2 = new FilePlayer(minim.loadFileStream(audioLayer2));
      player2.patch(out);

      //shift current recording to audioLayer1
      audioLayer1 = "test-recording" + recordCount + ".wav";
      player.unpatch(out);
      player.close();
      player = new FilePlayer(minim.loadFileStream(audioLayer1));
      player.patch(out);
      //
      recordCount = recordCount + 1;

      break;
  }
}  

void getSTATE(){
  if( myPort.available() > 0) {
    switchValue = myPort.read();
    println(switchValue);

    switch(switchValue){
      case '!':
        // case 1: pre-recorded sound + monitoring
        println("switchValue = 0");




        break;

      case '@':
        // case 2: 2 track of user recorded sound + monitoring
        println("switchValue = 1");




        break;

      case '#':

        println("switchValue = 2");

        break;



      case 'r':

        println("switchValue = r");

        key = 'r';
        keyReleased();

        break;



      case 's':

        println("switchValue = s");
        
        key = 'r';
        keyReleased();
        delay (50);
        key = 's';
        keyReleased();

        break;
    }

  }

  
}

void getButtonValue(){
  // if( myPort.available() > 0){
  //   recordButtonSTATE = myPort.read();
  // }

}


void recordSound(){


}

void saveRecordSound(){


}

