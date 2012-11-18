/* Menu Display */
void showmenu(){
  menulevel = MAINMENU;
  
  //lcdclear();
  lcdsetpos(0, 0);
  lcd.print("  ");
  if(curmenuitem == 0){
    lcd.print("-Main Menu-");
  }else{
    lcd.print(menuitems[curmenuitem-1]);
  }
  lcdsetpos(1, 0);
  lcd.write(rarrow); lcd.print(" ");
  lcd.print(menuitems[curmenuitem]);  
}

void showsubmenu(){
  menulevel = SUBMENU;
  
  //lcdclear();
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
  lcd.write(rarrow); lcd.print(" ");
  lcd.print(submenuitems[curmenuitem][cursubmenuitem]);
}
/* End Menu Display */

/* Menu Callbacks */
void menusetstatic(){
  displaystyle = STATIC;
  menureturn();
}

void menusetrotating(){
  displaystyle = ROTATING;
  menureturn();
}

void resetodometer(){
  odometer = 0;
  menureturn();
}

void menunothing(){
  return;
}

void menureturn(){
  lcdclear();
  curmenuitem = 0;
  cursubmenuitem = 0;
  if(menulevel == MAINMENU){
    displaystyle = prevdisplaystyle;
  }else{
    menulevel--;
  }
}
/* End Menu Callbacks */
