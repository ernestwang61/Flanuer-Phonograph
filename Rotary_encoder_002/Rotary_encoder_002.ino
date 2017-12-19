#include <HP20x_dev.h>
#include <KalmanFilter.h>

//  Rotary encoder reference
//  http://yehnan.blogspot.tw/2014/02/arduino.html

#include "SoftwareSerial.h"

#define SERIAL_BAUDRATE 115200
#define CLK_PIN 2 // 定義連接腳位
#define DT_PIN 3
#define SW_PIN 4

#define interruptA 0 // UNO腳位2是interrupt 0，其他板子請見官方網頁

#define FLEX_PIN 0

volatile int count = 0;
unsigned long t_flex = 0;
unsigned long t_rotary = 0;
unsigned long t_press = 0;
char mode;             //mode for differet sound sets

int flexSensorValue;
int buttonState = 0;
char recordState;      // start or stop&save recording

char charToSend[] = {'<', '0', '0', '0', '0', '>'};

int occupiedValue[] = {33, 35, 64, 114, 115};

void setup() {
  Serial.begin(SERIAL_BAUDRATE);
  // 當狀態下降時，代表旋轉編碼器被轉動了
  attachInterrupt(interruptA, rotaryEncoderChanged, FALLING);
  pinMode(CLK_PIN, INPUT_PULLUP); // 輸入模式並啟用內建上拉電阻
  pinMode(DT_PIN, INPUT_PULLUP); 
  pinMode(SW_PIN, INPUT_PULLUP); 
}

void loop() {
  
  
  readRotaryEncoder();
  readFlexSensor();
  updateSerial();
  

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
      charToSend[4] = recordState;
      
      // updateSerial();

      c++;
    }
  }

}


void readFlexSensor(){
  // [TODO] read flexSensorValue(0 - 1024), then send through serial port
  // option 1: find a way to combine different sensor's int value, and send through serial port,
  //            but the values has to be distinguishable on Processing side.
  // option 2: map flexSensorValue to 5 steps, use 5 different char indicate every steps.

  unsigned long temp = millis();
  if(temp - t_flex < 200) // 去彈跳
    return;
  t_flex = temp;

  flexSensorValue = analogRead(FLEX_PIN);

  for(int i = 0; i < 5; i++){
    if(flexSensorValue == occupiedValue[i])
      flexSensorValue += 5;
  } // 
  
  charToSend[1] = char(flexSensorValue);

  // Serial.write(flexSensorValue);

}

void rotaryEncoderChanged(){ // when CLK_PIN is FALLING
  unsigned long temp = millis();
  if(temp - t_rotary < 200) // 去彈跳
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
  charToSend[3] = mode;
  
  // updateSerial();

}


void updateSerial(){
  for(int i = 0; i < 6; i++){
    Serial.write(charToSend[i]);
    // if(i == 6)
    //   Serial.println(" ");
  } 

}





