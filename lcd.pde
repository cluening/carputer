// Some LCD helper functions
void lcdsetpos(uint8_t row, uint8_t col)
{
  int row_offsets[] = { 0x00, 0x40 };

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
