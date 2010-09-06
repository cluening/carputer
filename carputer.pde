#include <NewSoftSerial.h>
#include <TinyGPS.h>
#include <Fat16.h>
#include <Fat16util.h>

#define STATUSLED 13
#define DEBUG 0

TinyGPS gps;
NewSoftSerial nss(2, 3);
SdCard card;
Fat16 file;
bool fileisopen;
char filename[13] = "00000000.txt";
float prevlat, prevlon;

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

#if DEBUG == 1
  Serial.println("Awaiting fix...");
#endif
}

void loop(){
  bool newdata = false;
  unsigned long start = millis();
  float lat, lon;
  float alt, speed;
  unsigned long age;
  int year; 
  byte month, day, hour, minute, second;
  
  while(millis() - start < 1000){
    if(feedgps()){
      newdata = true;
    }
  }
  
  if(newdata){
    digitalWrite(STATUSLED, HIGH);
    gps.f_get_position(&lat, &lon, &age);
    alt = gps.f_altitude() * 3.2808399; // meters to feet
    speed = gps.f_speed_mph();
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
 * //Function to calculate the distance between two waypoints
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

#if DEBUG == 1
  Serial.print("Distance: ");
  Serial.println(dist_calc);
#endif
  return dist_calc;
}
