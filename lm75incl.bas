
Sub Lm75_init(byval Adresse As Byte)
Lm75_adresse = Adresse
End Sub

Sub Lm75_get_temp
Local Iicb1 As Byte
Local Iicb2 As Byte
Local Iicbt As Byte

I2cinit
I2cstart
Call I2cslave(lm75_adresse)
If I2cstat = 1 Then
   Call I2cout(lm75_temp_r)                                 ' //Register auf Temperatur setzen
   I2cstop
   I2cstart
   Iicbt = Lm75_adresse + 1
   Call I2cslave(iicbt)                                     'Bus -adresse Des Lm75 Schreiben
'//Liest einen Wert (2 Byte) vom LM75 Temperatursensor
   ' debug_log ("i2cLM75In".lf); ;
    Reset I2cnoack
    Iicb1 = I2cin()                                         '1. Byte Wert Vom Lm75 Lesen
    Set I2cnoack
    Iicb2 = I2cin()                                         '2. Byte Lesen
    Iicbt = Iicb1 And 128
    If Iicbt = 0 Then
        Lm75_temp = Iicb1                                   '              //Temperatur Vorkomma >= 0°C
    Else
        Lm75_temp = Iicb1 - 255                             '; / / Temperatur Vorkomma < 0°c
    End If
    Iicbt = Iicb2 And 128
    If Iicbt = 0 Then
        Reset Lm75_temp_nk
    Else
     Set Lm75_temp_nk
    End If
End If
End Sub