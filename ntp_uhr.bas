' NTP Clock with I2C-components
' Thomas Dressler 2009
'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
'--------------------------------------------------------------
'V1.0 Jan 2009
'V1.1 Jun 2009

$regfile = "m32def.dat"
$crystal = 16000000
$baud = 9600

'stack
$hwstack = 120
$swstack = 120
$framesize = 160



'Config Clock
Config Clock = User
Config Date = Dmy , Separator = .
Config Timer0 = Timer , Prescale = 1024                     'Timer for Systemclock
On Ovf0 Isr_timer0

'******************************  local data *************************************

Dim Timecount As Byte
Const Timeconst = 61                                        'Timeconst = 16000000 / 1024 / 256 for Timer0

Declare Sub Show_display()
Declare Sub Display_time
Declare Sub Display_temp

'variables for I2C
Dim I As Byte
Dim R As Byte
Dim T As Byte
Dim S As String * 16
Dim Bs(5) As String * 2
Dim Mb As Byte
Dim Time_local As Long


'************ Config I2C *******************************

' DP-Pin definitions
Dp1 Alias Portd.2                                           'NetIO ext. Header Pin 1
Dp2 Alias Portd.3                                           'NetIO ext. Header Pin 2
Config Dp1 = Output
Config Dp2 = Output

'I2C-Pins
Config Twi = 100000
Config Sda = Portb.0                                        'NetIO ext. Header Pin 7
Config Scl = Portb.3                                        'NetIO ext. Header Pin 8

'constant settings, maybe to change
Const Lm75adr = &H90                                        'lm75 base adresse
Const Pcf8583adr = &HA0                                     'PCF8583Base=160
Const Saa1064adr = &H70                                     'Saa1064Base=112
$include "i2cdecl.bas"
$include "saa1064decl.bas"
$include "pcf8583decl.bas"
$include "lm75decl.bas"


'****************** Config TCP **************************************************************
Const Use_dhcp = 0                                          'not working yet
Const Use_ntp = 1

'network parameter stored in EEPROM


Dim Ee_mac(6) As Eram Byte At 1
Dim Ee_ip As Eram Long At Ee_mac + 6
Dim Ee_mask As Eram Long At Ee_ip + 4
Dim Ee_gw As Eram Long At Ee_mask + 4
Dim Ee_gwmac(6) As Eram Byte At Ee_gw + 4
Dim Ee_ntp As Eram Long At Ee_gwmac + 6
Dim Ee_ntpoff As Eram Byte At Ee_ntp + 4
#if Use_dhcp = 1
Dim Ee_dns As Eram Long At Ee_ntpoff + 4
Dim Ee_hostnamelen As Eram Byte At Ee_dns + 4
Dim Ee_hostname As Eram String * 16 At Ee_dns + 5
#endif

'load networking declarations
$include "tcpdecl.bas"                                      'tcp variables
$include "enc28j60decl.bas"                                 'en28j60 variables
$lib "tcpip.lbx"                                            'we need it for the checksum calculation
#if Use_ntp = 1
$include "ntp_decl.bas"
#endif
#if Use_dhcp = 1
$include "dhcp_decl.bas"
#endif

Enc28j60_cs Alias Portb.4                                   'CS pin of the ENC28J60
Config Enc28j60_cs = Output

'Configuration of the SPI-bus
Enc28j60_int Alias Portb.2
Config Enc28j60_int = Input                                 'Interrupt Pin INT2
Enc28j60_int = 1                                            'Pullup
Config Int2 = Falling
On Int2 Isr_int2                                            'isr
Config Spi = Hard , Interrupt = Off , Data Order = Msb , Master = Yes , Polarity = Low , Phase = 0 , Clockrate = 4 , Noss = 1 , Spiin = 0
'init the spi pins
Spiinit


J11 Alias Portb.1
Config J11 = Input                                          'J11 to switch on DHCP
J11 = 1                                                     'Pullup

'Start mainprogram
Print
Print "Init I2C"

' ******************   init Display and pcf *********************
I2cinit
Set Dp1
Set Dp2
Call Saa1064_init(saa1064adr)
Call Pcf8583_init(pcf8583adr)
Call Lm75_init(lm75adr)


'display temperature first
Lm75_get_temp                                               'read temperature
Display_temp                                                'Display Temperature
Wait 10                                                     ' wait for switch to comeup

'procced
'inital clock set from pcf
Gosub Set_clock_from_pcf
Time_local = Syssec()
Timecount = 0
Show_display                                                'Update LED Display

'NO watchdog
'Config Watchdog = 4096
'


'****assign device config variables from eeprom ****
Print "Init Network"
'MAC address of the NET-IO

For Mb = 1 To 6
   En_mac(mb) = Ee_mac(mb)
Next Mb
   My_ip = Ee_ip
   My_mask = Ee_mask
For Mb = 1 To 6
   Mygw_mac(mb) = Ee_gwmac(mb)
Next Mb
   Mygw_ip = Ee_gw
#if Use_ntp = 1
'Fix Ip Address Of The Ntp Server
   Myntp_ip = Ee_ntp
   Myntp_off = Ee_ntpoff
#endif
#if Use_dhcp = 1
   Dhcp_name = Ee_hostname
#endif


'enable interupts
Enable Int2                                                 'enable interrupt 2 (ENC28j60_Int)
Enable Ovf0                                                 'systemclock
Enable Interrupts

'Reset the Enc28J60
Call Enc28j60_init

'
#if Use_dhcp = 1
If J11 = 1 Then
  Call Dhcp_discover                                        'DHCP request
End If
#endif

Print "MAC: " ; Hex(en_mac(1)) ; "-" ; Hex(en_mac(2)) ; "-" ; Hex(en_mac(3)) ; "-" ; Hex(en_mac(4)) ; "-" ; Hex(en_mac(5)) ; "-" ; Hex(en_mac(6))
Print "IP: " ; Myip(1) ; "." ; Myip(2) ; "." ; Myip(3) ; "." ; Myip(4)
Print "Netmask: " ; Mymask(1) ; "." ; Mymask(2) ; "." ; Mymask(3) ; "." ; Mymask(4)
Print "GW: " ; Mygw(1) ; "." ; Mygw(2) ; "." ; Mygw(3) ; "." ; Mygw(4)
Print "NTP: " ; Myntp(1) ; "." ; Myntp(2) ; "." ; Myntp(3) ; "." ; Myntp(4)

'Reset Watchdog
'get router mac by arprequest
Tcp_dest_ip = Mygw_ip
Call Tcp_arpquery
If Arp_ready = 1 Then
'If Tcp_destmac(1) < 255 And Tcp_destmac(1) > 0then
   'MAC address of your Router/Gateway , located by ARP
   For Mb = 1 To 6
      Mygw_mac(mb) = Tcp_destmac(mb)                        'sore fore usage
      Ee_gwmac(mb) = Tcp_destmac(mb)                        'store to eeprom
   Next Mb


Else
   Print "WARNING:No Arp response, use stored value"
End If
Print "GW MAC-Adresse: " ; Hex(mygw_mac(1)) ; "-" ; Hex(mygw_mac(2)) ; "-" ; Hex(mygw_mac(3)) ; "-" ; Hex(mygw_mac(4)) ; "-" ; Hex(mygw_mac(5)) ; "-" ; Hex(mygw_mac(6))
Print

#if Use_ntp = 1
   Call Ntp_request                                         ' start ntp query, will hanled in mainloop
#endif

Print "NTP-Uhr started"
'#####################################  mainloop  #########################################

Do
   Gosub Checkfor_netdata                                   ' ask for new data
   #if Use_ntp = 1
   If Ntp_ready = 255 Then
         Time_local = Ntp_local
         Gosub Getdatetime                                  'correct ntp_local
         Gosub Set_clock_to_pcf                             'set PCF8583time
   End If
   If Ntp_ready > 10 Then
      If Ntp_ready = 255 Then
         Print "Got NTP Answer"
      Else
         Print "NO NTP_Answer!"
      End If
      Ntp_ready = 0                                         ' reset ntp_query pointer
   End If
   #endif
   T = Inkey()

   If T > 0 Then
      Select Case T
         Case &H53 : Gosub Set_pcf_date                     ' Taste S
         Case &H73 : Gosub Set_pcf_time                     ' Taste s
         Case &H47 : Gosub Print_date                       ' Taste G
         Case &H67 : Gosub Print_time                       ' Taste g
         Case &H74 : Gosub Print_temp                       ' Taste t
      End Select
   End If

   'clock
   If Timecount > Timeconst Then

   'every second
      Incr Time_local
      Gosub Getdatetime
      Timecount = 0

      Show_display                                          'Update LED Display
      #if Use_ntp = 1
      If Ntp_ready > 0 Then
         Call Ntp_request                                   'ntp query activ, create new request
      End If
      #endif



      If _sec = 59 Then
      'every minute
         If _min = 59 Then
         'every hour a new query
         #if Use_ntp = 1
            Call Ntp_request
         #else
            Gosub Set_clock_from_pcf                        'get PCF8583time

         #endif
         End If

         Lm75_get_temp                                      'read temperature
         Print Date$ ; " " ; Time$ ; " ";                   '
         Gosub Print_temp
      End If

   End If
Loop
End

'##################################   end mainloop   ######################################





'****************************** net routines **********************

$include "en28j60_routines.bas"                             ' the ENC28J60-routines
$include "tcp_routines.bas"                                 ' the net-routines
#if Use_ntp = 1
$include "ntp_routines.bas"
#endif
#if Use_dhcp = 1
$include "dhcp_routines.bas"
#endif

'**********I2C-Code ***************************

$include "i2cincl.bas"
$include "saa1064incl.bas"
$include "pcf8583incl.bas"
$include "lm75incl.bas"



'*****************************  ISR  *****************************************
Isr_int2:
  Tcp_data_present = 1

Return

'timer0 for clock
Isr_timer0:
   Incr Timecount
Return

'******************* local Subroutines **********************************
'clock routines
Setdate:

Return

Settime:

Return

Getdatetime:
   Time$ = Time(time_local)
   Date$ = Date(time_local)
Return

Set_sys_time:
   _sec = Pcf8583_sekunde
   _min = Pcf8583_minute
   _hour = Pcf8583_stunde
Return
Set_sys_date:
   _day = Pcf8583_tag
   _month = Pcf8583_monat
   _year = Pcf8583_jahr + 8                                 'hardcoded for year after 2008
Return

'set pcf to current time
Set_clock_to_pcf:
   Pcf8583_sekunde = _sec
   Pcf8583_minute = _min
   Pcf8583_stunde = _hour

   Pcf8583_tag = _day
   Pcf8583_monat = _month
   Pcf8583_jahr = _year
   Pcf8583_wtag = Dayofweek()
   Call Pcf8583_set_time(pcf8583_stunde , Pcf8583_minute , Pcf8583_sekunde)
   Call Pcf8583_set_date(pcf8583_tag , Pcf8583_monat , Pcf8583_jahr , Pcf8583_wtag)
Return

'Set Time manually to pcf
Set_pcf_time:
   Input "Set Time( HH:MI:SS ): >" , S
   T = Split(s , Bs(1) , ":")
   If T = 5 Then
      R = Val(bs(1))
      If R >= 0 And R < 24 Then
         Pcf8583_stunde = R
      End If
      R = Val(bs(3))

      If R >= 0 And R < 60 Then
         Pcf8583_minute = R
      End If
      R = Val(bs(5))

      If R >= 0 And R < 60 Then
         Pcf8583_sekunde = R
      End If
      Call Pcf8583_set_time(pcf8583_stunde , Pcf8583_minute , Pcf8583_sekunde)
      Gosub Set_sys_time
      Time_local = Syssec()
   End If
Return



'Set Datum manually to pcf
Set_pcf_date:
   Input "Set Date( DD.MM.YY ): >" , S
   T = Split(s , Bs(1) , ".")

   If T = 5 Then
      R = Val(bs(1))

      If R > 0 And R < 32 Then
         Pcf8583_tag = R
      End If
      R = Val(bs(3))

      If R > 0 And R < 13 Then
         Pcf8583_monat = R
      End If
      R = Val(bs(5))

      Pcf8583_jahr = R
      Gosub Set_sys_date
      Time_local = Syssec()
      Pcf8583_wtag = Dayofweek()
      Call Pcf8583_set_date(pcf8583_tag , Pcf8583_monat , Pcf8583_jahr , Pcf8583_wtag)
   End If
Return

'print Datum
Print_date:
   Print _day ; "." ; _month ; "." ; _year
Return

'print Time
Print_time:
   Print _hour ; ":" ; _min ; ":" ; _sec
Return

'print Temperatur
Print_temp:
   Print Lm75_temp ;
   If Lm75_temp_nk = 0 Then
      Print ".0"
   Else
      Print ".5"
   End If
Return

'set system clock with date/time from pcf8583
Set_clock_from_pcf:
   Pcf8583_get_date
   Pcf8583_get_time
   _sec = Pcf8583_sekunde
   _min = Pcf8583_minute
   _hour = Pcf8583_stunde
   _day = Pcf8583_tag
   _month = Pcf8583_monat
   _year = Pcf8583_jahr + 8
   Print "Set Clock from PCF to: " ; _day ; "." ; _month ; "." ; _year ; "   " ; _hour ; ":" ; _min ; ":" ; _sec
Return


'************ LED Display Routines **********
'refresh Display with actual time
Sub Show_display()
   Toggle Dp1
   ' every 16sec for 4 sec show temperature instead of time
   R = _sec And &B00001100
   If R = 0 Then
      Call Display_temp
   Else
      Toggle Dp2
      Call Display_time
   End If
End Sub


' Show temperature on LED
Sub Display_temp
'

   R = Lm75_temp
   R = Bin_to_bcd(r)
   Shift R , Right , 4                                      'BCD-High Hour
   Gosub Seg_lookup
   Saa1064_data(1) = R
   R = Lm75_temp                                            'BCD_Low Hour
   R = Bin_to_bcd(r)
   Gosub Seg_lookup
   Set R.7
   Saa1064_data(2) = R
   If Lm75_temp_nk = 0 Then
      R = 0
   Else
      R = 5
   End If
   Gosub Seg_lookup
   Saa1064_data(3) = R
   R = Lookup(0 , 7seg_special)
   Saa1064_data(4) = R
   If Lm75_temp < 0 Then
      Set Saa1064_data(4).2
   End If
   Saa1064_out
End Sub


' Show Time on LED
Sub Display_time
   R = _hour
   R = Bin_to_bcd(r)
   Shift R , Right , 4                                      'BCD-High Hour
   Gosub Seg_lookup
   Saa1064_data(1) = R
   R = _hour                                                'BCD_Low Hour
   R = Bin_to_bcd(r)
   Gosub Seg_lookup
   Saa1064_data(2) = R
   R = _min                                                 'BCD High Minute
   R = Bin_to_bcd(r)
   Shift R , Right , 4
   Gosub Seg_lookup
   Saa1064_data(3) = R
   R = _min                                                 'BCD-Low Minute
   R = Bin_to_bcd(r)
   Gosub Seg_lookup
   Saa1064_data(4) = R
   R = _sec And 3                                           'get digit for floating Decimalpoint
   Incr R
   Set Saa1064_data(r).7                                    'Decimalpoint set
   For I = 1 To 4
      R = Saa1064_data(i)
   Next I
   Saa1064_out
End Sub


'lookup for 7segment display
Seg_lookup:
   R = R And &H0F
   If R < 10 Then
    R = Lookup(r , 7seg_num)
   Else
     R = 0
   End If
Return


' ********* DATA ****************
'  0-9 in 7segments
7seg_num:
' num.  0      1      2      3      4      5      6      7      8      9
Data &H3F , &H06 , &H5B , &H4F , &H66 , &H6D , &H7D , &H07 , &H7F , &H6F
' num.  A      B      C      D      E      F

7seg_special:
' char GRD
Data &H63

'default net data
$eeprom
Initlen:
Data 28
Macaddr:
Data &H00 , &H22 , &HF9 , &HF1 , &HAB , &H02
Ipaddr:
Data 192 , 168 , 101 , 103
Netmask:
Data 255 , 255 , 255 , 0
Gwip:
Data 192 , 168 , 101 , 1
Gwmac:
Data &H00 , &H1A , &H4F , &H86 , &H7C , &HC7
Ntpip:
Data 192 , 53 , 103 , 108
Ntpoff:
Data 1
Dnsip:
Data 192 , 168 , 101 , 3
Hostname:
Data 7 , "NTPCLOCK"
$data