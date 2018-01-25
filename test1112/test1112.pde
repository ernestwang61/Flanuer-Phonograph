//  serial connection ref:
//  http://coopermaa2nd.blogspot.tw/2011/03/processing-arduino.html

import processing.serial.*;
import ddf.minim.*;
import ddf.minim.ugens.*;
import ddf.minim.spi.*; //for AudioStream
import ddf.minim.effects.*;


Serial myPort;
int switchValue;
int flexSensorValue;
int occupiedValue[] = {33, 35, 64, 114, 115};
boolean recordButtonSTATE;

boolean newData = false;
int numChars = 4;
char receivedChars[] = {'0','0','0','0'};

int state = 0;

Minim minim;

FilePlayer player;
FilePlayer player2;

// for monitoring
LiveInput liveIn;

// for recording
AudioInput in;
AudioRecorder recorder;
boolean recorded;

// for playing back
AudioOutput out;
AudioOutput out2;
FilePlayer player3;

// for bandpass filter
BandPass bpf;

String AudioLayer1;
String AudioLayer2;
String userAudioLayer1 = "NTUST_Sounds_E.wav";
String userAudioLayer2 = "NTUST_Sounds_E.wav";
String historyAudioLayer1 = "NTUST_Sounds_Jar.mp3";
String historyAudioLayer2 = "NTUST_Sounds_Jar.mp3";

int recordCount_H = 0;
int recordCount_U = 0;
int recordCount_3 = 0;

int previousSTATE = 0;

int sliderValue;
int ultraSonicValue;
char mode;
char recordState;

void setup()
{
  size(512, 200, P3D);
  
  // we pass this to Minim so that it can load files from the data directory
  minim = new Minim(this);
  out = minim.getLineOut( Minim.STEREO );
  out2 = minim.getLineOut(Minim.STEREO);
  in = minim.getLineIn(Minim.STEREO); // use the getLineIn method of the Minim object to get an AudioInput

  // we ask for an input with the same audio properties as the output.
  AudioStream inputStream = minim.getInputStream( out.getFormat().getChannels(), 
                                                  out.bufferSize(), 
                                                  out.sampleRate(), 
                                                  out.getFormat().getSampleSizeInBits());

  
  // construct a LiveInput by giving it an InputStream from minim.  
  liveIn = new LiveInput( inputStream );

  bpf = new BandPass(440, 20, out.sampleRate());
  // liveIn.patch( bpf ).patch( out2 );
  
  out.setGain(-20.0);
  
  // loadFile will look in all the same places as loadImage does.
  // this means you can find files that are in the data folder and the 
  // sketch folder. you can also pass an absolute path, or a URL.
  player = new FilePlayer( minim.loadFileStream( historyAudioLayer1 ));
  player2 = new FilePlayer( minim.loadFileStream( historyAudioLayer2 ));
  // player3 = new FilePlayer( minim.loadFileStream(in));

  recorder = minim.createRecorder(out2, "test-recording-start.wav");


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
  
  //in.enableMonitoring();

  String monitoringState = in.isMonitoring() ? "enabled" : "disabled";
  text( "Input monitoring is currently " + monitoringState + ".", 5, 15 );



  //show text if it's recording
  if ( recorder.isRecording() )
  {
    text("Now recording, press the r key to stop recording.", 5, 40);
  }
  // else if ( !recorded )
  // {
  //   text("Press the r key to start recording.", 5, 40);
  // }
  else
  {
    text("Press the s key to save the recording to disk.", 5, 40);
  }  

  getSerial();
  getSensorValue();
  setSTATE();



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
      println("userAudioLayer1 = " + userAudioLayer1);

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
      println("userAudioLayer2 = " + userAudioLayer2);

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
  switch(key){
    case 'r':
      print("recordCount_H = ");
      println(recordCount_H);
      print("recordCount_U = ");
      println(recordCount_U);
      print("state = ");
      println(state);

      if(state == 0){
        recorder = minim.createRecorder(out2, "history-recording" + recordCount_H + ".wav");
        recordCount_H++;
      }
      else if(state == 1){
        recorder = minim.createRecorder(out2, "user-recording" + recordCount_U + ".wav");
        recordCount_U++;
      }
      else if(state == 2){
        recorder = minim.createRecorder(out2, "mode3-recording" + recordCount_3 + ".wav");
        recordCount_3++;
      }

      recorder.beginRecord();
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
      if ( recorder.isRecording() ) 
      {
        recorder.endRecord();
        recorder.save();
      }

      if ( player3 != null )
      {
        player3.unpatch( out );
        player3.close();
      }

      // player3 = new FilePlayer( recorder.save() );
      // player3.patch( out );
      // player3.play();

      //player.close();
      //player2.close();

      switch(state){
        // case 0:
        //   AudioLayer1 = historyAudioLayer1;
        //   AudioLayer2 = historyAudioLayer2;
          
        //   loadSoundFile();

        //   player.loop();
        //   player2.loop();

        //   break;

        case 1:

          int recordCount_fileName = recordCount_U - 1;

          userAudioLayer2 = userAudioLayer1;
          userAudioLayer1 = "user-recording" + recordCount_fileName + ".wav";
          
          AudioLayer1 = userAudioLayer1;
          AudioLayer2 = userAudioLayer2;
          loadSoundFile();

          player.loop();
          player2.loop();

          break;

        case 2:

          break;
      }


      // if(state == 2){
      // //shift userAudioLayer1 to userAudioLayer2
      //   //player2 = player;
      //   userAudioLayer2 = userAudioLayer1;
      //   // player2.unpatch(out);
      //   // player2.close();
      //   // player2 = new FilePlayer(minim.loadFileStream(userAudioLayer2));
      //   // player2.patch(out);

      // //shift current recording to userAudioLayer1
      //   userAudioLayer1 = "user-recording" + recordCount_U + ".wav";
      //   // player.unpatch(out);
      //   // player.close();
      //   // player = new FilePlayer(minim.loadFileStream(userAudioLayer1));
      //   // player.patch(out);
      //   //

      //   AudioLayer1 = userAudioLayer1;
      //   AudioLayer2 = userAudioLayer2;
      //   loadSoundFile();
      // }

      break;
  }
}  


int incomingNum;
void getSerial(){
  if(myPort.available() > 0){
    incomingNum = myPort.read();
    //println(incomingNum);
  }

}


void getSensorValue() {
    for(int i = 0; i < 5; i++){
      if(incomingNum == occupiedValue[i]){
        switch(incomingNum){
          case '!':
            mode = '!';
            break;
          case '@':
            mode = '@';
            break;
          case '#':
            mode = '#';
            break;
          case 'r':
            mode = 'r';
            break;
          case 's':
            mode = 's';
            break;
        }
      }
      else if(incomingNum%2 == 0){
        sliderValue = incomingNum;
      }
      else{
        ultraSonicValue = incomingNum;
      }
    }

    setBandpass();

    // print("sliderValue: ");
    // println(sliderValue);
    // print("ultraSonicValue: ");
    // println(ultraSonicValue);

}



void setSTATE(){ 

  if(mode == previousSTATE)
    return;
  else{
    switch(mode){
      case '!':
        // case 1: pre-recorded sound + monitoring
        if(previousSTATE != 114){
          println("mode = 0");

          liveIn.unpatch( out2 );
          liveIn.patch( out2 );

          AudioLayer1 = historyAudioLayer1;
          AudioLayer2 = historyAudioLayer2;
          loadSoundFile();

          player.loop();
          player2.loop();

          state = 0;

          previousSTATE = 33;
        }
        break;

      case '@':
        // case 2: 2 track of user recorded sound + monitoring
        if(previousSTATE != 114){
          println("mode = 1");

          liveIn.unpatch( out2 );
          liveIn.patch( bpf ).patch( out2 );

          AudioLayer1 = userAudioLayer1;
          AudioLayer2 = userAudioLayer2;
          loadSoundFile();

          player.loop();
          player2.loop();

          state = 1;

          previousSTATE = 64;
        }
        break;

      case '#':
        if(previousSTATE != 114){
          println("mode = 2");

          liveIn.unpatch( out2 );
          liveIn.patch( bpf ).patch( out2 );

          player.unpatch(out);
          player.close();
          player2.unpatch(out);
          player2.close();
          state = 2;

          previousSTATE = 35;
        }
        break;



      case 'r':

        println("recordState = r");

        key = 'r';
        keyReleased();

        previousSTATE = 114;
        break;



      case 's':

        println("recordState = s");
        
        // key = 'r';
        // keyReleased();
        // delay (50);
        key = 's';
        keyReleased();

        previousSTATE = 115;
        break;
    }
  }
}


void loadSoundFile(){ 
  player.unpatch(out);
  player.close();
  player = new FilePlayer(minim.loadFileStream(AudioLayer1));
  player.patch(out); 
  
  player2.unpatch(out);
  player2.close();
  player2 = new FilePlayer(minim.loadFileStream(AudioLayer2));
  player2.patch(out);


}




// to change bandpass filter value
//[TODO]固定bandwidth, 身高高低控制frequency
//[TODO] slider 控制音量
//[TODO] 找常見聲音頻率範圍
//[TODO] 440hz 為基礎
// 一般高度、 蹲下、抬高 >> 希望達成什麼樣的效果(interaction vision)
void setBandpass()
{
  float bandWidth = 500;
  bpf.setBandWidth(bandWidth);

  // map the mouse position to the range [100, 10000], an arbitrary range of passBand frequencies
  float passBand = map(ultraSonicValue, 0, 255, 100, 1000); 
  bpf.setFreq(passBand);
  print("BandPass Freq:");
  println(passBand);
  // float bandWidth = map(ultraSonicValue, 0, 255, 50, 500);
  // bpf.setBandWidth(bandWidth);

  // prints the new values of the coefficients in the console
  //bpf.printCoeff();
  float gain = map(sliderValue, 0, 255, 1, 60);
  out2.setGain(gain);
  print("Out2 gain:");
  println(gain);


}
