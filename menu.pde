/* Menu Display */
void showmenu(){
  menulevel = MAINMENU;
  
  lcdclear();
  lcdsetpos(0, 0);
  lcd.print("  ");
  if(curmenuitem == 0){
    lcd.print("-Main Menu-");
  }else{
    lcd.print(menuitems[curmenuitem-1]);
  }
  lcdsetpos(1, 0);
  lcd.print(rarrow, BYTE); lcd.print(" ");
  lcd.print(menuitems[curmenuitem]);  
}

void showsubmenu(){
  menulevel = SUBMENU;
  
  lcdclear();
  lcdsetpos(0, 0);
  if(cursubmenuitem == 0){
    lcd.print("-");
    lcd.print(menuitems[curmenuitem]);
    lcd.print("-");
  }else{
    lcd.print("  ");
    lcd.print(submenuitems[curmenuitem][cursubmenuitem-1]);
  }
  lcdsetpos(1, 0);
  lcd.print(rarrow, BYTE); lcd.print(" ");
  lcd.print(submenuitems[curmenuitem][cursubmenuitem]);
}
/* End Menu Display */

/* Menu Callbacks */
void menunothing(){
  return;
}

void menureturn(){
  curmenuitem = 0;
  cursubmenuitem = 0;
  if(menulevel == MAINMENU){
    displaystyle = prevdisplaystyle;
  }else{
    menulevel--;
  }
}
/* End Menu Callbacks */
