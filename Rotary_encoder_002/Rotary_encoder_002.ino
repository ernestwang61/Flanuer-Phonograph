//  Rotary encoder reference
//  http://yehnan.blogspot.tw/2014/02/arduino.html

#include <Ultrasonic.h>
#include <HP20x_dev.h>
#include <KalmanFilter.h>
#include <Adafruit_NeoPixel.h>
#include "SoftwareSerial.h"

#define SERIAL_BAUDRATE 115200
#define CLK_PIN 2 // 定義連接腳位
#define DT_PIN 3
#define SW_PIN 4

#define interruptA 0 // UNO腳位2是interrupt 0，其他板子請見官方網頁

#define FLEX_PIN 0

volatile int count = 0;
unsigned long t_slider = 0;
unsigned long t_rotary = 0;
unsigned long t_press = 0;
unsigned long t_uSonic = 0;
char mode;             //mode for differet sound sets

int flexSensorValue;
int ultrasonicValue;

int buttonState = 0;
char recordState;      // start or stop&save recording

int charToSend = 0;

int occupiedValue[] = {33, 35, 64, 114, 115};

#define TRIGGER_PIN  12
#define ECHO_PIN     13
Ultrasonic ultrasonic(TRIGGER_PIN, ECHO_PIN);

#define LED_1 6
#define LED_2 7
#define LED_3 8

#define neo_PIN 10
Adafruit_NeoPixel strip = Adafruit_NeoPixel(60, neo_PIN, NEO_GRB + NEO_KHZ800);

//============================================

void setup() {
  Serial.begin(SERIAL_BAUDRATE);
  // 當狀態下降時，代表旋轉編碼器被轉動了
  attachInterrupt(interruptA, rotaryEncoderChanged, FALLING);
  pinMode(CLK_PIN, INPUT_PULLUP); // 輸入模式並啟用內建上拉電阻
  pinMode(DT_PIN, INPUT_PULLUP); 
  pinMode(SW_PIN, INPUT_PULLUP); 

  // setup neopixel
  strip.begin();
  strip.setBrightness(30);
  strip.show();
}

void loop() {
  
  
  readRotaryEncoder();
  readSlider();
  readUltrasonic();
  setLED();
  setLED_neo();
  //updateSerial();
  

}




//========================================

int c;
void readRotaryEncoder(){
  unsigned long temp = millis();
  if(temp - t_press < 100) // 去彈跳
    return;
  t_press = temp;


  if(digitalRead(SW_PIN) == HIGH)
    c = 0;
  else if(digitalRead(SW_PIN) == LOW){ // 偵測開關是否被按下
    // count = 0;  
    // Serial.println("count reset to 0");
    // delay(300);

    if(c == 0){
    //button pressed, then start recording. Pressed again, stop recording
      buttonState = abs(buttonState - 1); //flip buttonState everytime when button is pressed
    
      if(buttonState == 0){
        recordState = 's';
      }
      else if(buttonState == 1){
        recordState = 'r';
      }
      // [TODO] send through serial port
      charToSend = recordState;
      
      updateSerial();

      c++;
    }
  }

}


void readSlider(){
  // [TODO] read flexSensorValue(0 - 1024), then send through serial port
  // option 1: find a way to combine different sensor's int value, and send through serial port,
  //            but the values has to be distinguishable on Processing side.
  // option 2: map flexSensorValue to 5 steps, use 5 different char indicate every steps.

  unsigned long temp = millis();
  if(temp - t_slider < 100) // 去彈跳
    return;
  t_slider = temp;

  flexSensorValue = analogRead(FLEX_PIN);
  flexSensorValue = map(flexSensorValue, 0, 1023, 0, 254);
  //only send even number
  if(flexSensorValue % 2 == 1)
    flexSensorValue++;

  //check if sensor value bump into occupiedValue, if so, shift the value up
  for(int i = 0; i < 5; i++){
    if(flexSensorValue == occupiedValue[i])
      flexSensorValue += 2;
  } 
  
  charToSend = flexSensorValue;
  updateSerial();
  
  // Serial.print("flexSensorValue: ");
  // Serial.println(flexSensorValue);


}

void rotaryEncoderChanged(){ // when CLK_PIN is FALLING
  unsigned long temp = millis();
  if(temp - t_rotary < 100 || recordState == 'r') // 去彈跳
    return;
  t_rotary = temp;
  
  // DT_PIN的狀態代表正轉或逆轉
  count += digitalRead(DT_PIN) == HIGH ? 1 : -1;
  if(count > 2){
    count = 2;
  }
  else if(count < 0){
    count = 0;
  }


  switch(count){
    case 0:
      mode = '!';
      break;
    case 1:
      mode = '@';
      break;
    case 2:
      mode = '#';
      break;
  }

  // Serial.println(count);
  // Serial.write(count);
  // Serial.println(mode);
  // Serial.write(mode);
  charToSend = mode;
  
  updateSerial();

}


void updateSerial(){
  
  // for(int i = 0; i < 6; i++){
    Serial.write(charToSend);
    // if(i == 6)
    //   Serial.println(" ");
  // } 

  //Serial.println(charToSend);

}


void readUltrasonic(){
  int uSonic_threshold = 200; //unit: cm

  unsigned long temp = millis();
  if(temp - t_uSonic < 100) // read every 200ms
    return;
  t_uSonic = temp;

  float cmMsec;
  long microsec = ultrasonic.timing();

  cmMsec = ultrasonic.convert(microsec, Ultrasonic::CM);
  if(cmMsec > uSonic_threshold)
    cmMsec = uSonic_threshold;

  ultrasonicValue = map(int(cmMsec), 0, uSonic_threshold, 0, 255);
  
  if (ultrasonicValue % 2 == 0)
    ultrasonicValue++;
  
  for(int i = 0; i < 5; i++){
    if(ultrasonicValue == occupiedValue[i])
      ultrasonicValue += 2;
  } 

  charToSend = ultrasonicValue;
  updateSerial(); 
}

void setLED(){
  switch(mode){
    case '!':
      digitalWrite(LED_1, HIGH);
      digitalWrite(LED_2, LOW);
      digitalWrite(LED_3, LOW);
      break;

    case '@':
      digitalWrite(LED_1, LOW);
      digitalWrite(LED_2, HIGH);
      digitalWrite(LED_3, LOW);
      break;

    case '#':
      digitalWrite(LED_1, LOW);
      digitalWrite(LED_2, LOW);
      digitalWrite(LED_3, HIGH);
      break;
  }
}

void setLED_neo(){
  int r, g, b;
  for(int i = 0; i < 3; i++)
    strip.setPixelColor(i, 0, 0, 0);
  
  if(recordState == 'r'){
    r = 100;
    g = 0;
    b = 0;
  }
  else{
    r = 40;
    g = 72;
    b = 99;
  }
  strip.setPixelColor(count, r, g, b);
  strip.show();
}








