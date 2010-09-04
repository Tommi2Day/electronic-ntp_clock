'/*
'LM75 operations
'Register=0 Temperatur
'Register=2 Schaltpunkt
'Register=3 Hysterese
'*/
Const Lm75_temp_r = 0
Const Lm75_conf_r = 1
Const Lm75_sp_r = 2
Const Lm75_hyst_r = 3
Dim Lm75_temp As Integer
Dim Lm75_temp_nk As Bit
Dim Lm75_adresse As Byte

Declare Sub Lm75_init(byval Adresse As Byte)
Declare Sub Lm75_get_temp