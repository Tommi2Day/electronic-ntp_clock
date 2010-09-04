'Include for SAA1064
'translated from PHP-Lib
' (C) Thomas Dressler 2008

'Declarations needed:
Declare Sub Saa1064_out
Declare Sub Saa1064_control_out
Declare Sub Saa1064_init(byval Adresse As Byte )
Dim Saa1064_data(4) As Byte
Dim Saa1064_control As Byte
Dim Saa1064_adresse As Byte