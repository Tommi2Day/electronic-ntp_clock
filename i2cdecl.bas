'Definitions for I2C glue library
'translatre syntax into php/perl library format
' (C) thomas dressler 2008
Declare Sub I2cslave(byval Adresse As Byte)
Declare Sub I2cout(byval Dbyte As Byte)
Declare Function I2cin() As Byte
Dim I2cstat As Bit
Dim I2cnoack As Bit
Const I2c_debug = 0