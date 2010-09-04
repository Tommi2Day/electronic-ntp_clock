
'Include for PCF8583
'translated from PHP-Lib
'Declarations needed:
'$include "pcf8583decl.bas"
' (C) Thomas Dressler 2008

Sub Pcf8583_init(byval Adresse As Byte)
Pcf8583_adresse = Adresse
End Sub

Function Bin_to_bcd(byval Datab As Byte) As Byte
Local Tempu As Byte
Local Templ As Byte

    Tempu = Datab / 10
    Shift Tempu , Left , 4
    Templ = Datab Mod 10
    Bin_to_bcd = Tempu + Templ
End Function


Function Bcd_to_bin(datab As Byte) As Byte
Local Tempu As Byte
Local Templ As Byte
   Tempu = Datab
   Shift Tempu , Right , 4
    Tempu = Tempu * 10
    Templ = Datab And 15
    Bcd_to_bin = Tempu + Templ
End Function


Function Pcf8583_read_byte(byval Register As Byte) As Byte
Local Iicb As Byte
    I2cinit
    I2cstart
    Iicb = 255
    Call I2cslave(pcf8583_adresse)
    If I2cstat = 1 Then

      Call I2cout(register)                                 ' Register Setzen
      I2cstop
      I2cstart
      Iicb = Pcf8583_adresse + 1
      Call I2cslave(iicb)
      Set I2cnoack
      Iicb = I2cin()
      'i2cNoAck();
      I2cstop
   End If
  Pcf8583_read_byte = Iicb
End Function

Sub Pcf8583_write_byte(byval Register As Byte , Byval Datab As Byte)
Local Iicb As Byte
    I2cinit
    I2cstart
    Call I2cslave(pcf8583_adresse)
    If I2cstat = 1 Then
      Call I2cout(register)                                 'internes Register setzen
      I2cstop
      I2cstart
      'B = D & 255;
      Call I2cout(datab)
    End If
  I2cstop

End Sub

Sub Pcf8583_write_word(byval Register As Byte , Byval Dataw As Word)
Local Iicb As Byte
    I2cinit
    I2cstart
    Call I2cslave(pcf8583_adresse)
    If I2cstat = 1 Then
         Call I2cout(register)                              ' / / Internes Register Setzen
         I2cstop
         I2cstart
         Iicb = Low(dataw)
         Call I2cout(iicb)
         Iicb = High(dataw)
   'if ($ret) {
         Call I2cout(iicb)
   '}
   End If
  I2cstop
End Sub

Function Pcf8583_get_status() As Byte
Local Iicb As Byte
  Iicb = Pcf8583_read_byte(pcf8583_status_r)                '{ RAM-Adresse 0 ansprechen }
  Pcf8583_get_status = Iicb
End Function

Sub Pcf8583_set_status(byval Datab As Byte)
  Call Pcf8583_write_byte(pcf8583_status_r , Datab)
  If I2cstat = 1 Then
   Pcf8583_status_merker = Datab                            '{ Status In Merker Sichern }
  End If
End Sub

Sub Pcf8583_set_time(byval Stunde As Byte , Byval Minute As Byte , Byval Sekunde As Byte)
Local Iicb As Byte
'    Debug_log( "PCF8583_SetTime:$stunde:$minute:$sekunde".lf);
'  Uhrzeit setzen
'/* Eingabe  : stunde  : Stunden  0..24                           */
'/*            minute  : Minuten  0..59                           */
'/*            sekunde : Sekunden 0..59                           */

    'Print "Set Time entered:" ; Stunde ; ":" ; Minute ; ":" ; Sekunde

    I2cinit
    I2cstart
    Call I2cslave(pcf8583_adresse)
    If I2cstat = 1 Then
                                       ' //auto increment
      Call I2cout(pcf8583_status_r)                         '; //Status Register setzen
      Iicb = Pcf8583_status_merker Or Pcf8583_stop_count
      Call I2cout(iicb)                                     '; //{ Uhr anhalten }
      Call I2cout(0)                                        '; //hundert
      Iicb = Bin_to_bcd(sekunde)
      Call I2cout(iicb)
      Iicb = Bin_to_bcd(minute)
      Call I2cout(iicb)
      Iicb = Bin_to_bcd(stunde)
      Call I2cout(iicb)
        I2cstop
        I2cstart
      Call I2cslave(pcf8583_adresse)
      Call I2cout(pcf8583_status_r)
      Call I2cout(pcf8583_status_merker)
   End If
   I2cstop
End Sub

Sub Pcf8583_set_date(byval Tag As Byte , Byval Monat As Byte , Byval Jahr As Byte , Byval Wtag As Byte)
Local Iicb As Byte
Local Tempb As Byte
'    debug_log ("PCF8583_SetDate:$tag.$monat.$jahr ($wtag)".lf);
'Print "Set Date entered:" ; Tag ; ":" ; Monat ; ":" ; Jahr ; "->WD:" ; Wtag


 I2cinit
 I2cstart
 Call I2cslave(pcf8583_adresse)
 If I2cstat = 1 Then
  Call I2cout(pcf8583_status_r)                             ' //Status Register setzen
  Iicb = Pcf8583_status_merker Or Pcf8583_stop_count
  Call I2cout(iicb)                                         '; //{ Uhr anhalten }
  I2cstop
  I2cstart
  Call I2cslave(pcf8583_adresse)
  Call I2cout(pcf8583_jahr_r)
  Tempb = Jahr
  Shift Tempb , Left , 6
  Pcf8583_sjahr = Tempb
  Iicb = Bin_to_bcd(tag)
  'debug_log("Tag:BCD=".b.lf);
  Iicb = Tempb Or Iicb
'  Print "Tag:" ; Hex(iicb)
  Call I2cout(iicb)                                         '; //register 5 (jahr+datum)
  Tempb = Wtag
  Shift Tempb , Left , 5
  Iicb = Bin_to_bcd(monat)
  'Debug_log( "Monat:BCD=".b.lf);
  Iicb = Tempb Or Iicb
'  Print "Monat:" ; Hex(iicb)
  Call I2cout(iicb)                                         ' //register 6($monat+$wtag)
  I2cstop
  I2cstart
  Call I2cslave(pcf8583_adresse)
  Call I2cout(pcf8583_status_r)                             ' //Status Register setzen
  Call I2cout(pcf8583_status_merker)                        '
 End If
 I2cstop
End Sub

Sub Pcf8583_get_time
Local Iicb As Byte
#if I2c_debug = 1
 Print "PCF8583_GetTime entered"
#endif
    I2cinit
    I2cstart
    Call I2cslave(pcf8583_adresse)
    If I2cstat = 1 Then
      Call I2cout(2)                                        ' / / Register Setzen
      I2cstop
      Reset I2cnoack
      I2cstart
      Iicb = Pcf8583_adresse + 1
      Call I2cslave(iicb)
        Iicb = I2cin()
        Pcf8583_sekunde = Bcd_to_bin(iicb)
        'i2cAck();
        Iicb = I2cin()
        Pcf8583_minute = Bcd_to_bin(iicb)
        'i2cAck();
        Set I2cnoack
        Iicb = I2cin()
        Iicb = Iicb And 63
        Pcf8583_stunde = Bcd_to_bin(iicb)
        'I2cnoack
        I2cstop
#if I2c_debug = 1
        Print "PCF8583_GetTime_Result:" ; Pcf8583_stunde ; ":" ; Pcf8583_minute ; ":" ; Pcf8583_sekunde
        'Pcf8583_get_time = Sprintf( "%02d:%02d:%02d" , Stunde , Minute , Sekunde);
 Else
    Print "PCF8583_get_time Error"
#endif
   End If

End Sub

Sub Pcf8583_get_date
Local Iicb As Byte
Local Iici As Byte

Reset I2cnoack
 'Weekdays = Array(                                          'So','Mo','Di','Mi','Do','Fr','Sa');
 'debug_log ("PCF8583_GetDate entered".lf);

' $mytime=localtime();
' $sj=$mytime[5]-100;
' $sj=$sj & 0xFC;
#if I2c_debug = 1
   Print "PCF_Get_date entered"
#endif
 I2cinit
 I2cstart
 Call I2cslave(pcf8583_adresse)
 If I2cstat = 1 Then
  Call I2cout(pcf8583_jahr_r)                               '; //Read Register setzen
  I2cstop
  I2cstart
  Iicb = Pcf8583_adresse + 1
  Call I2cslave(iicb)                                       '; //read adresse
  Iici = I2cin()
  Iicb = Iici And 63
  Pcf8583_tag = Bcd_to_bin(iicb)
  Shift Iici , Right , 6
  Pcf8583_jahr = Iici + Pcf8583_sjahr
  'I2cack
  Set I2cnoack
  Iici = I2cin()
  Iicb = Iici And 31
  Pcf8583_monat = Bcd_to_bin(iicb)
  Shift Iici , Right , 5
  Pcf8583_wtag = Iici
  'Wd = Weekdays[wtag]
  'debug_log ("PCF8583_GetDate_Result:$tag.$monat.$jahr =WD:$wtag:$wd".lf);
  'i2cNoAck
  I2cstop
#if I2c_debug = 1
        Print "PCF8583_Get_Date_Result:" ; Pcf8583_tag ; ":" ; Pcf8583_monat ; ":" ; Pcf8583_jahr
  'Pcf8583_get_date = Sprintf( "%02d.%02d.%02d (%s)" , Tag , Monat , Jahr , Wd);
 Else
    Print "PCF8583_get_date Error"
#endif


 End If
End Sub
