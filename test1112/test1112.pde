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
AudioOutput out_other;
AudioOutput out_main;
FilePlayer player3;

// for bandpass filter
BandPass bpf;

String AudioLayer1;
String AudioLayer2;
String historyAudioLayer1 = "Flaneur Phonograph_history_BoWen.wav";
String historyAudioLayer2 = "Flaneur Phonograph_history_BoWen.wav";
// String userAudioLayer1 = "REC006_01_online.wav";
// String userAudioLayer2 = "REC006_01_online.wav";
String userAudioLayer1;
String userAudioLayer2;

int recordCount_H = 0;
int recordCount_U = 0;
int recordCount_3 = 0;
JSONArray RecordList;

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
  out_other = minim.getLineOut( Minim.STEREO );
  out_main = minim.getLineOut(Minim.STEREO);
  in = minim.getLineIn(Minim.STEREO); // use the getLineIn method of the Minim object to get an AudioInput

  // we ask for an input with the same audio properties as the output.
  AudioStream inputStream = minim.getInputStream( out_other.getFormat().getChannels(), 
                                                  out_other.bufferSize(), 
                                                  out_other.sampleRate(), 
                                                  out_other.getFormat().getSampleSizeInBits());

  
  // construct a LiveInput by giving it an InputStream from minim.  
  liveIn = new LiveInput( inputStream );

  bpf = new BandPass(440, 20, out_other.sampleRate());
  // liveIn.patch( bpf ).patch( out_main );
  
  out_other.setGain(0.0);
  out_main.setGain(50.0);
  
  // loadFile will look in all the same places as loadImage does.
  // this means you can find files that are in the data folder and the 
  // sketch folder. you can also pass an absolute path, or a URL.
  player = new FilePlayer( minim.loadFileStream( historyAudioLayer1 ));
  player2 = new FilePlayer( minim.loadFileStream( historyAudioLayer2 ));
  // player3 = new FilePlayer( minim.loadFileStream(in));

  recorder = minim.createRecorder(out_main, "test-recording-start.wav");


  player.patch(out_other);
  player2.patch(out_other);

//////// Serial connection /////////////
  textFont(createFont("Arial", 12));
  printArray(Serial.list());
  String portName = Serial.list()[1];
  myPort = new Serial(this, portName, 115200);


//////// Get latest user recorded file ///////////
  RecordList = loadJSONArray("recordList.json");
  recordCount_U = RecordList.size();
  print("recordCount_U = ");
  println(recordCount_U);

  JSONObject userRecording1 = RecordList.getJSONObject(recordCount_U - 1 );
  String userRecording_Title1 = userRecording1.getString("file title");
  JSONObject userRecording2 = RecordList.getJSONObject(recordCount_U - 2 );
  String userRecording_Title2 = userRecording2.getString("file title");

  userAudioLayer1 = userRecording_Title1;
  userAudioLayer2 = userRecording_Title2;

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
  setGain(sliderValue);



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
  
int rY = 0;
int rM = 0;
int rD = 0;
int rh = 0;
int rm = 0;
int rs = 0;
String recordTitle;
JSONObject newRecording;

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
        recorder = minim.createRecorder(out_main, "history-recording" + recordCount_H + ".wav");
        recordCount_H++;
      }
      else if(state == 1){
        int Y = year();
        int M = month();
        int D = day();
        int h = hour();
        int m = minute();
        int s = second();

        rY = Y;
        rM = M;
        rD = D;
        rh = h;
        rm = m;
        rs = s;
        
        recordTitle= "user-recording" + rY + rM + rD + "_" + rh + "_" + rm + "_" + rs + ".wav";

        newRecording = new JSONObject();
      
        int i = RecordList.size();
        newRecording.setInt("id", i);
        newRecording.setString("type", "user");
        newRecording.setString("file title", recordTitle);
        RecordList.setJSONObject(i, newRecording);
        saveJSONArray(RecordList, "data/recordList.json");

        recorder = minim.createRecorder(out_main, recordTitle);
        
      }
      else if(state == 2){
        recorder = minim.createRecorder(out_main, "mode3-recording" + recordCount_3 + ".wav");
        recordCount_3++;
      }

      recorder.beginRecord();
      break;

    case 's':
      // we've filled the file out_other buffer, 
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
        player3.unpatch( out_other );
        player3.close();
      }

      // player3 = new FilePlayer( recorder.save() );
      // player3.patch( out_other );
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

          userAudioLayer2 = userAudioLayer1; //shift previous recording to 2nd layer

          // get new recording file name
          JSONObject userRecording1 = RecordList.getJSONObject(RecordList.size()-1);
          String file_title = userRecording1.getString("file title"); 
          userAudioLayer1 = file_title;

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
      //   // player2.unpatch(out_other);
      //   // player2.close();
      //   // player2 = new FilePlayer(minim.loadFileStream(userAudioLayer2));
      //   // player2.patch(out_other);

      // //shift current recording to userAudioLayer1
      //   userAudioLayer1 = "user-recording" + recordCount_U + ".wav";
      //   // player.unpatch(out_other);
      //   // player.close();
      //   // player = new FilePlayer(minim.loadFileStream(userAudioLayer1));
      //   // player.patch(out_other);
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

    // setFilter();

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
          println("mode = history");

          AudioLayer1 = historyAudioLayer1;
          AudioLayer2 = historyAudioLayer2;
          loadSoundFile();

          player.loop();
          // player2.loop();

          int random = int(random((7*60+55)*1000));     
          // int random_2 = int(random(1*60*1000));

          player.cue(random);
          // player2.cue(random_2);


          state = 0;

          previousSTATE = 33;
        }
        liveIn.unpatch( out_main );
        // setFilter(ultraSonicValue, 1, sliderValue, 1); //[TODO] 裝置高度對應到什麼？prepared sound mode應該要如何改變聲音？
        // setFilter(int passBandValue, int bandPass_output, int gainValue, int gain_output) //output: 1 or 2

        liveIn.patch( out_main );

        break;

      case '@':
        // case 2: 2 track of user recorded sound + monitoring
        if(previousSTATE != 114){
          println("mode = user");

          AudioLayer1 = userAudioLayer1;
          AudioLayer2 = userAudioLayer2;
          loadSoundFile();

          player.loop();
          player2.loop();

          state = 1;

          previousSTATE = 64;
        }
        liveIn.unpatch( out_main );
        // setFilter();
        liveIn.patch( out_main );

        break;

      case '#':
        if(previousSTATE != 114){
          println("mode = no Effects");

          liveIn.unpatch( out_main );
          liveIn.patch( out_main );

          player.unpatch(out_other);
          player.close();
          player2.unpatch(out_other);
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
  player.unpatch(out_other);
  player.close();
  player = new FilePlayer(minim.loadFileStream(AudioLayer1));
  player.patch(out_other); 
  
  player2.unpatch(out_other);
  player2.close();
  player2 = new FilePlayer(minim.loadFileStream(AudioLayer2));
  player2.patch(out_other);


}




// to change bandpass filter value
//[TODO]固定bandwidth, 身高高低控制frequency
//[TODO] slider 控制音量
//[TODO] 找常見聲音頻率範圍
//[TODO] 440hz 為基礎
// 一般高度、 蹲下、抬高 >> 希望達成什麼樣的效果(interaction vision)
// 一班高度：70-100, 蹲下：0-70, 抬高: 100-150
void setFilter(int passBandValue, int bandPass_output, int gainValue, int gain_output)
{
  float bandWidth = 500;
  bpf.setBandWidth(bandWidth);

  // map the mouse position to the range [100, 10000], an arbitrary range of passBand frequencies
  float passBand = map(passBandValue, 0, 255, 100, 1000); 
  bpf.setFreq(passBand);
  print("BandPass Freq:");
  println(passBand);
  // float bandWidth = map(ultraSonicValue, 0, 255, 50, 500);
  // bpf.setBandWidth(bandWidth);\


  // prints the new values of the coefficients in the console
  //bpf.printCoeff();
  float gain = map(gainValue, 0, 255, 1, 60);
  if(gain_output == 1){
    out_other.setGain(gain);
    print("Out_other gain:");
  }
  else if (gain_output == 2){
    out_main.setGain(gain);
    print("Out_main gain:");
  }
  println(gain);

}

void setGain(int gainValue){
  float gain_main = map(gainValue, 0, 255, 20, 80);
  out_main.setGain(gain_main);

  float gain_other = map(gainValue, 0, 255, 20, -20);
  out_other.setGain(gain_other);

}
