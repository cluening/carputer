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
#include "carputer.h"

#define VERSION "0.8"

TinyGPS gps;
NewSoftSerial nss(2, 3);
NewSoftSerial lcd(255, 7);
SdCard card;
Fat16 file;
bool fileisopen;
char filename[13] = "00000000.txt";
float prevlat, prevlon;
int screen = 0;
byte displaystyle = STATIC, prevdisplaystyle;
unsigned long screenmillis = 0;
byte upstate, downstate, buttonstate;
float odometer = 0;

bool feedgps();

/* Menu Pieces */
byte menulevel = MAINMENU, curmenuitem = 0, cursubmenuitem = 0;

byte nummenuitems = 4;
char *menuitems[] = {
  "Display Mode",
  "Reset Odometer",
  "Version Info",
  "Return"
};
void (*menucallbacks[])() = {
  &showsubmenu,
  &resetodometer,
  &showsubmenu,
  &menureturn
};


byte numsubmenuitems[] = {3, 2, 0};
char *submenuitems[][3] = {
  {
    "Static",
    "Rotating",
    "Return"
  }, {
    "Version " VERSION,
    "Return"
  }
};
void(*submenucallbacks[][3])() = {
  {
    &menusetstatic,
    &menusetrotating,
    &menureturn
  }, {
    &menunothing,
    &menureturn
  }
};

/* End Menu Pieces */

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

  /* Check the rollerball for updates */
  if(digitalRead(UPPIN) == !upstate){
    upcount++;
    if(upcount > 5){
      if(displaystyle == MENU){
        if(menulevel == MAINMENU){
          if(curmenuitem > 0) curmenuitem--;
        }else if(menulevel == SUBMENU){
          if(cursubmenuitem > 0) cursubmenuitem--;
        }
      }else{
        if(screen > 0) screen--;
      }
      upcount = 0;
      downcount = 0;
    }
    upstate = !upstate;
  }
  if(digitalRead(DOWNPIN) == !downstate){
    downcount++;
    if(downcount > 5){
      if(displaystyle == MENU){
        if(menulevel == MAINMENU){
          if(curmenuitem < nummenuitems-1) curmenuitem++;
        }else if(menulevel == SUBMENU){
          if(cursubmenuitem < numsubmenuitems[curmenuitem]-1) cursubmenuitem++;
        }
      }else{
        if(screen < NUMSCREENS-1) screen++;
      }
      upcount = 0;
      downcount = 0;
    }
    downstate = !downstate;
  }
  if(digitalRead(BUTTONPIN) == !buttonstate){
    buttonstate = !buttonstate;
    if(buttonstate == LOW){
      if(displaystyle != MENU){
        prevdisplaystyle = displaystyle;
        displaystyle = MENU;
      }else{
        if(menulevel == MAINMENU){
          menucallbacks[curmenuitem]();
        }else if(menulevel == SUBMENU){
          submenucallbacks[curmenuitem][cursubmenuitem]();
        }
      }
    }
  }
  /* Done checking roller */

  
  if(feedgps()){
    newdata = true;
  }
  
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
      if(menulevel == MAINMENU) showmenu();
      else if(menulevel == SUBMENU) showsubmenu();
    }else{
      if(displaystyle == ROTATING){
        curmillis = millis();
        if(curmillis - screenmillis > 5000){
          screen++;
          screen %= NUMSCREENS;
          screenmillis = curmillis;
        }
      }

      /* Display the proper screen */
      if(screen == GENERAL){
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
      }else if(screen == LATLON){
        /* Latitude/Longitude */
        //lcdclear();
        lcdsetpos(0, 0);
        lcd.print("Lat: ");
        lcdprintdms(lat);
        lcdsetpos(1, 0);
        lcd.print("Lon: ");
        lcdprintdms(lon);
      }else if(screen == ODOMETER){
        lcdclear();
        lcd.print("-Trip  Odometer-");
        lcd.print("    ");
        if(odometer < 528){
          lcd.print((int)odometer);
          lcd.print(" ft");
        }else{
          lcd.print(odometer/5280.0, 1);
          lcd.print(" mi");
        }
      }else{
        lcdclear();
        lcd.print("Invalid screen");
      }
    }
    
    if(calc_dist(prevlat, prevlon, lat, lon) > 10){
      odometer += 10;
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



bool feedgps()
{
  while (nss.available())
  {
    if (gps.encode(nss.read()))
      return true;
  }
  return false;
}


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
