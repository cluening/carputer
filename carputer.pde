/*
 * The Car Computer
 * ----------------
 * Tracks everywhere the car goes
 * In the future:
 *  - Will interface with the OBD port
 */

#include <NewSoftSerial.h>
#include <TinyGPS.h>
#include <Fat16.h>
#include <Fat16util.h>

#define STATUSLED 13
#define DEBUG 1

#define UPPIN 4
#define DOWNPIN 5
#define BUTTONPIN 6

#define STATIC 0
#define ROTATING 1
#define MENU 2

#define rarrow 0x7E

TinyGPS gps;
NewSoftSerial nss(2, 3);
NewSoftSerial lcd(255, 7);
SdCard card;
Fat16 file;
bool fileisopen;
char filename[13] = "00000000.txt";
float prevlat, prevlon;
int screen = 0;
byte displaystyle = ROTATING, prevdisplaystyle = ROTATING;
byte numscreens = 2;
unsigned long screenmillis = 0;
byte upstate, downstate, buttonstate;
byte curoption = 0;
  
bool feedgps();

// SD Helpers
#if DEBUG == 1
#define error(s) error_P(PSTR(s))
#else
#define error(s) error_C(s)
#endif

void error_P(const char* str) {
  PgmPrint("error: ");
  SerialPrintln_P(str);
  if (card.errorCode) {
    PgmPrint("SD error: ");
    Serial.println(card.errorCode, HEX);
  }
  while(1);
}

void error_C(const char *str) {
  digitalWrite(STATUSLED, HIGH);
  lcdclear();
  lcd.print("SD Error");
  while(1);
}
// End SD Helpers

void setup(){
#if DEBUG == 1
  Serial.begin(9600);
#endif

  prevlat = 500;
  prevlon = 500;

  // Start listening for GPS info
  nss.begin(4800);

  // Initialize the SDcard library
  pinMode(8, OUTPUT);
  fileisopen = false;
  if(!card.init(1, 8)) error("card.init");
  Fat16::init(&card);

  // Initialize the roller ball
  upstate = (digitalRead(UPPIN));
  downstate = (digitalRead(DOWNPIN));
  buttonstate = HIGH;

  lcd.begin(9600);
  lcdclear();
  lcd.print("Awaiting fix...");

#if DEBUG == 1
  Serial.println("Awaiting fix...");
#endif
}

void loop(){
  bool newdata = false;
  unsigned long curmillis;
  float lat, lon;
  float alt, speed, course;
  unsigned long age;
  int year; 
  byte month, day, hour, minute, second, tzhour;
  float min, sec;

  static byte upcount = 0;
  static byte downcount = 0;

  // Check roller
  if(digitalRead(UPPIN) == !upstate){
    if(displaystyle == MENU){
      upcount++;
      if(upcount > 5){
        if(curoption > 0) curoption--;
        upcount = 0;
      }
    }
    upstate = !upstate;
#if DEBUG == 1
    Serial.print("Up! ");
    Serial.println((int)curoption);
#endif
  }
  if(digitalRead(DOWNPIN) == !downstate){
    if(displaystyle == MENU){
      downcount++;
      if(downcount > 5){
        curoption++;
        downcount = 0;
      }
    }
    downstate = !downstate;
#if DEBUG == 1
    Serial.print("Down! ");
    Serial.println((int)curoption);
#endif
  }
  if(digitalRead(BUTTONPIN) == !buttonstate){
    buttonstate = !buttonstate;
    if(buttonstate == LOW){
#if DEBUG == 1
      Serial.println("Clicked!");
#endif
      if(displaystyle != MENU){
        prevdisplaystyle = displaystyle;
        displaystyle = MENU;
      }else{
        if(curoption == 2){
          displaystyle = prevdisplaystyle;
        }
      }
    }
  }
  
  //while(millis() - start < 1000){
    if(feedgps()){
      newdata = true;
    }
  //}
  
  if(newdata){
    digitalWrite(STATUSLED, HIGH);
    gps.f_get_position(&lat, &lon, &age);
    alt = gps.f_altitude() * 3.2808399; // meters to feet
    speed = gps.f_speed_mph();
    course = gps.course();
    if(speed < 1){
      speed = 0;
    }
    gps.crack_datetime(&year, &month, &day, &hour, &minute, &second);

    if(fileisopen == false && year != 2000){
      setfilename(filename, year, month, day);
#if DEBUG == 1
      Serial.println(filename);
#endif
      if(file.open(filename, O_CREAT | O_WRITE | O_APPEND)){
        fileisopen = true;
        file.print("---TRACK---\n");
      }else{
        digitalWrite(STATUSLED, HIGH);
#if DEBUG == 1
        error("file.open");
#endif
      }
    }

    if(displaystyle == MENU){
      showmenu();
    }else{
      if(displaystyle == ROTATING){
        curmillis = millis();
        if(curmillis - screenmillis > 5000){
          screen++;
          screen %= numscreens;
          screenmillis = curmillis;
        }
      }

      /* Display the proper screen */
      if(screen == 0){
        /* Default screen */
        lcdclear();
        tzhour = (hour - 6 + 24) % 24;
        if(tzhour < 10) lcd.print("0");
        if(tzhour > 12){
          lcd.print((int)tzhour - 12);
        }else if(tzhour == 0){
          lcd.print(12);
        }else{
          lcd.print((int)tzhour);
        }
        lcd.print(":"); 
        if(minute < 10) lcd.print("0");
        lcd.print((int)minute);
        if(tzhour > 11){
          lcd.print("pm");
        }else{
         lcd.print("am");
        }
        lcdsetpos(0, 9);
        if(speed < 10) lcd.print(" ");
        lcd.print(speed, 1);
        lcd.print("mph");
      }else if(screen == 1){
        /* Latitude/Longitude */
        //lcdclear();
        lcdsetpos(0, 0);
        lcd.print("Lat: ");
        lcdprintdms(lat);
        lcdsetpos(1, 0);
        lcd.print("Lon: ");
        lcdprintdms(lon);
      }else{
        lcdclear();
        lcd.print("Invalid screen");
      }
    }
    
    if(calc_dist(prevlat, prevlon, lat, lon) > 10){
      file.print(lat, 6);      file.print(" ");
      file.print(lon, 6);      file.print(" ");
      file.print(speed, 1);    file.print(" ");
      file.print(alt);         file.print(" ");
      file.print(year);        file.print("-");
      file.print((int)month);  file.print("-");
      file.print((int)day);    file.print(" ");
      file.print((int)hour);   file.print(":");
      file.print((int)minute); file.print(":");
      file.print((int)second); file.print("\n");

#if DEBUG == 1
      Serial.print(lat, 6);      Serial.print(" ");
      Serial.print(lon, 6);      Serial.print(" ");
      Serial.print(speed, 1);    Serial.print(" ");
      Serial.print(alt);         Serial.print(" ");
      Serial.print(year);        Serial.print("-");
      Serial.print((int)month);  Serial.print("-");
      Serial.print((int)day);    Serial.print(" ");
      Serial.print((int)hour);   Serial.print(":");
      Serial.print((int)minute); Serial.print(":");
      Serial.print((int)second); Serial.print("\n");
#endif

      file.sync();
      prevlat = lat;
      prevlon = lon;
    }

    digitalWrite(STATUSLED, LOW);
  }
}

/* Menu Bits */
void showmenu(){
  byte numoptions = 3;
  char *options[] = {
    "Display Style",
    "Nothing",
    "Return"
  };

  if(curoption >= numoptions){
    curoption = numoptions - 1;
  }
  if(curoption <=0){
    curoption = 0;
  }

  lcdclear();
  lcdsetpos(0, 0);
  lcd.print("  ");
  if(curoption == 0){
    lcd.print("-Main Menu-");
  }else{
    lcd.print(options[curoption-1]);
  }
  lcdsetpos(1, 0);
  lcd.print(rarrow, BYTE);
  lcd.print(" ");
  lcd.print(options[curoption]);  
}

void showsubmenu(byte top){
  
}

void showsubsubmenu(byte top, byte sub){
  
}
/* End Menu Bits */

bool feedgps()
{
  while (nss.available())
  {
    if (gps.encode(nss.read()))
      return true;
  }
  return false;
}

// Some LCD helper functions
void lcdsetpos(uint8_t row, uint8_t col)
{
  int row_offsets[] = { 0x00, 0x40, 0x14, 0x54 };

  lcdcommand();
  lcd.print(0x80 | (col + row_offsets[row]), BYTE);
}

void lcdclear(){
  lcdcommand();
  lcd.print(0x01, BYTE);
}

void lcdcommand(){
  lcd.print(0xFE, BYTE);
}

void lcdprintdms(float deg){
  float min, sec;
  
  min = fabs(60.0*(deg - int(deg)));
  sec = 60.0*(min - int(min));
  if(deg > 0) lcd.print(" ");
  if(abs(deg) < 100) lcd.print(" ");
  if(abs(deg) < 10) lcd.print(" ");
  lcd.print(int(deg));lcd.print(0xDF, BYTE);
  if(min < 10) lcd.print("0");
  lcd.print(int(min));lcd.print("'");
  if(sec < 10) lcd.print("0");
  lcd.print(int(sec));lcd.print('"'); 
}
// End LCD helper functions


// Sets the filename to the given date.  Expects that the character
// buffer is already primed with '.txt\0' at the end.
void setfilename(char *filename, int year, int month, int day){
  long fulltime = (long)year*10000L + (long)month*100L + (long)day;
  int i;

#if DEBUG == 1
  Serial.print(year); Serial.print(month); Serial.println(day);
  Serial.println(fulltime);
#endif

  for(i=0;i<8;i++){
    filename[7-i] = fulltime % 10 + '0';
    fulltime /= 10;
  }
}

/*************************************************************************
 * Function to calculate the distance between two waypoints
 * Stolen from the arduino forums
 *************************************************************************/
float calc_dist(float flat1, float flon1, float flat2, float flon2) {
  float dist_calc=0;
  float dist_calc2=0;
  float diflat=0;
  float diflon=0;

  //I've to spplit all the calculation in several steps. If i try to do it in a single line the arduino will explode.
  diflat=radians(flat2-flat1);
  flat1=radians(flat1);
  flat2=radians(flat2);
  diflon=radians((flon2)-(flon1));

  dist_calc = (sin(diflat/2.0)*sin(diflat/2.0));
  dist_calc2= cos(flat1);
  dist_calc2*=cos(flat2);
  dist_calc2*=sin(diflon/2.0);
  dist_calc2*=sin(diflon/2.0);
  dist_calc +=dist_calc2;

  dist_calc=(2*atan2(sqrt(dist_calc),sqrt(1.0-dist_calc)));

  dist_calc*=20902231.0; //Converting to feet

  return dist_calc;
}
