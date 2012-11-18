// Some LCD helper functions
void lcdsetpos(uint8_t row, uint8_t col)
{
  int row_offsets[] = { 0x00, 0x40 };

  lcdcommand();
  lcd.write(0x80 | (col + row_offsets[row]));
}

void lcdclear(){
  lcdcommand();
  lcd.write(0x01);
}

void lcdcommand(){
  lcd.write(0xFE);
}

void lcdprintdms(float deg){
  float min, sec;

  min = fabs(60.0*(deg - int(deg)));
  sec = 60.0*(min - int(min));
  if(deg > 0) lcd.print(" ");
  if(abs(deg) < 100) lcd.print(" ");
  if(abs(deg) < 10) lcd.print(" ");
  lcd.print(int(deg));lcd.write(0xDF);
  if(min < 10) lcd.print("0");
  lcd.print(int(min));lcd.print("'");
  if(sec < 10) lcd.print("0");
  lcd.print(int(sec));lcd.print('"'); 

}


void lcdprintheading(float course){
  char *headings[] = {
    "N", "NNE", "NE", 
    "ENE", "E", "ESE", 
    "SE", "SSE", "S", "SSW", "SW", 
    "WSW", "W", "WNW", 
    "NW", "NNW", "N"
  };

  lcd.print(headings[map(course, 0, 360, 0, 16)]);
}
