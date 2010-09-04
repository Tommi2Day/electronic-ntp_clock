

Dim Pcf8583_status_merker As Byte
Dim Pcf8583_sekunde As Byte
Dim Pcf8583_minute As Byte
Dim Pcf8583_stunde As Byte
Dim Pcf8583_wtag As Byte
Dim Pcf8583_tag As Byte
Dim Pcf8583_monat As Byte
Dim Pcf8583_jahr As Byte
Dim Pcf8583_sjahr As Byte
Dim Pcf8583_adresse As Byte



Declare Function Bin_to_bcd(byval Datab As Byte) As Byte
Declare Function Bcd_to_bin(byval Datab As Byte) As Byte
Declare Sub Pcf8583_init(byval Adresse as byte)

Declare Function Pcf8583_read_byte(byval Register As Byte) As Byte
Declare Sub Pcf8583_write_byte(byval Register As Byte , Byval Datab As Byte)
'Declare Sub Pcf8583_write_byte(Byval Register As Byte , Byval Datab As Byte)
Declare Sub Pcf8583_write_word(byval Register As Byte , Byval Dataw As Word)
Declare Function Pcf8583_get_status() As Byte
Declare Sub Pcf8583_set_status(byval Datab As Byte)

Declare Sub Pcf8583_set_time(byval Stunde As Byte , Byval Minute As Byte , Byval Sekunde As Byte)
Declare Sub Pcf8583_set_date(byval Tag As Byte , Byval Monat As Byte , Byval Jahr As Byte , Byval Wtag As Byte )
Declare Sub Pcf8583_get_time
Declare Sub Pcf8583_get_date

Pcf8583_status_merker = 0

'PCF8583 operations

Const Pcf8583_base = 160
Const Pcf8583_sec_flag = 1
Const Pcf8583_min_flag = 2
Const Pcf8583_alarm_enable = 4
Const Pcf8583_mask_flag = 8
Const Pcf8583_mode_32khz = 0
Const Pcf8583_mode_50hz = &H10
Const Pcf8583_counter_mode = &H20
Const Pcf8583_test_mode = &H30
Const Pcf8583_hold_count = &H40
Const Pcf8583_stop_count = &H80
'Registers
Const Pcf8583_status_r = 0
Const Pcf8583_sekunde_r = 2
Const Pcf8583_jahr_r = 5
Const Pcf8583_timer_r = 7
Const Pcf8583_alarm_status_r = 8
Const Pcf8583_alarm_timer_r = 15