#!/usr/bin/perl -w

my($line, @line, $lat, $lon, $speed, $ele, $date, $time, $datetime);
my($year, $month, $day, $hour, $minute, $second);
my $segcount = 0;

print(qq(<?xml version="1.0" encoding="UTF-8" standalone="no" ?>\n));
print(qq(<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">\n));

print(qq(  <trk>\n));
while($line = <STDIN>){
  chop $line;

  if($line eq "---TRACK---"){
    if($segcount > 0){
      print(qq(    </trkseg>\n));
    }
    print(qq(    <trkseg>\n));
    $segcount++;
  }else{
    ($lat, $lon, $speed, $ele, $date, $time) = split(/\s+/, $line);

    ($year, $month, $day) = split(/-/, $date);
    ($hour, $minute, $second) = split(/:/, $time);
    $datetime = sprintf("%4.4d-%2.2d-%2.2dT%2.2d:%2.2d:%2.2dZ", $year, $month, $day, $hour, $minute, $second);

    print(qq(      <trkpt lat="$lat" lon="$lon">\n));
    print(qq(        <ele>$ele</ele>\n));
    print(qq(        <time>$datetime</time>\n));
    print(qq(      </trkpt>\n));
  }
}
print(qq(    </trkseg>\n));
print(qq(  </trk>\n));
print(qq(</gpx>\n));
