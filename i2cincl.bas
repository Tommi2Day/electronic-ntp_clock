'I2C glue library
'translatre syntax into php/perl library format
' (C) thomas dressler 2008

Sub I2cslave(byval Adresse As Byte)

   I2cwbyte Adresse
   If Err = 0 Then
       Set I2cstat
   Else
      Reset I2cstat
   End If
End Sub


Sub I2cout(byval Dbyte As Byte)
   I2cwbyte Dbyte
   If Err = 0 Then
       Set I2cstat
   Else
      Reset I2cstat
   End If
End Sub

Function I2cin() As Byte
Local Iicb As Byte

   If I2cnoack = 1 Then
      I2crbyte Iicb , Nack
   Else
      I2crbyte Iicb , Ack
   End If
   If Err = 0 Then
       Set I2cstat
   Else
      Reset I2cstat
   End If
   I2cin = Iicb
End Function