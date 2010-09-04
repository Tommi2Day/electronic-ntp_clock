
'Include for SAA1064
'translated from PHP-Lib
'Declarations needed:
'$include "saa1064decl.bas"
' (C) Thomas Dressler 2008

'Initialization
Sub Saa1064_init(byval Adresse As Byte)                     ' init block
Local Iicb As Byte
   Saa1064_adresse = Adresse
   Saa1064_control = &B11110111                             'dynamic mode, max intensity
   For Iicb = 1 To 4                                        'Digit1-4
    Saa1064_data(iicb) = 0                                  'all segments off
   Next If
   Call Saa1064_out                                         'Send all To Device
End Sub





Sub Saa1064_out
'{ Ausgabe von Daten auf den SAA 1064
'  Eingabe    adr     : 0..3  IIC-Adresse des SAA1064
'             control : Control-Register
'             daten   : Feld mit 4 Eintr„gen = Inhalt der Anzeigen
'  Rckgabe : 0 : kein ACK vom Slave empfangen --> šbertragungsfehler
'             1 : ACK vom Slave empfangen --> šbertragung ok
'}
'*/

Local Iicb As Byte
Local Iici As Byte

I2cinit
I2cstart
Call I2cslave(saa1064_adresse)
If I2cstat = 1 Then
  Call I2cout(0)                                            '; //control register
  Call I2cout(saa1064_control)
  For Iici = 1 To 4
   Iicb = Saa1064_data(iici)                                '
   Call I2cout(iicb)
  Next Iici

  End If
  I2cstop
End Sub


'send only control byte
Sub Saa1064_control_out
'/*
'{ Ausgabe des Control-Bytes auf den SAA 1064
'  Eingabe Adr : 0..3 Iic -adresse Des Saa1064
'             control : Control-Register
'  Rckgabe : 0 : kein ACK vom Slave empfangen --> šbertragungsfehler
'             1 : ACK vom Slave empfangen --> šbertragung ok
'}
'0x07 aus
'0x37 an
' bit0 = dynamic mode
' bit1 = digit 1+3 not blanked
' bit2 = digit 2+4 not blanked
' bit3 = test segment
' bit4 = 3mA segment current
' bit5 = 6mA segment current
' bit6 = 12mA segment current
' bit7 = indifferent
'*/
'$CONTROL_BYTE = $control;
I2cinit
I2cstart
Call I2cslave(saa1064_adresse)
If I2cstat = 1 Then
  Call I2cout(0)                                            '; //control register
   Call I2cout(saa1064_control)
  End If
  I2cstop
End Sub
'

' **************************************************************************************