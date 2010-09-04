' NTP Clock with I2C-components
' Thomas Dressler 2009
'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
'--------------------------------------------------------------

' Routine to get the NetWork Time from a time-server

Sub Ntp_query

   Local Ntp_loop As Byte
   Ntp_ready = 0
   Do
   'resend request every 0,2s , 10 times
      If Ntp_ready < 10 Then
         Call Ntp_request
         For Ntp_loop = 1 To 20
            'check answer for 2s
            Waitms 100
            Gosub Checkfor_netdata
            If Ntp_ready = 255 Then
                  Exit For
            End If
         Next Ntp_loop
      End If

   Loop Until Ntp_ready = 10
End Sub

'create request for network time from timeserver
Sub Ntp_request
   Local Ntp_b As Byte
   Local Ntp_pcktlen As Word
   'Mac-header =============
   Tcp_dest_ip = Myntp_ip

   'get dest mac (router or local network mac
   Call Tcp_arpquery

   Call Tcp_clearbuff                                       'Clear the complete tcp_buffer

   'fill buffer
   Gosub Tcp_ethernet_header
   T_enetpackettype = T_packet_ip                           'ip

   'IP-header ==============

   T_ip_vers_len = T_def_vers_len                           'header length
   T_ip_tos = T_def_tos                                     'Type of service

   T_ip_pktlen0 = High(ntp_packet_len)                      'total length
   T_ip_pktlen1 = Low(ntp_packet_len)

   T_ip_id0 = &H10                                          'IDentification
   T_ip_id1 = &H9B

   T_ip_flags = T_def_flags                                 'flags --> not fragmented

   T_ip_offset = T_def_offset                               'fragment offset

   T_ip_ttl = T_def_ttl                                     'TTL

   T_ip_proto = T_prot_udp                                  'protocol UDP

   '25 is checksum
   '26 is checksum

   T_ip_srcaddr = My_ip
   T_ip_destaddr = Tcp_dest_ip

   'source port 123
   T_udp_srcport = T_port_ntp
   'destination port 123 --> ntp server
   T_udp_destport = T_port_ntp
   'T_udp_len0 = &H00                                        'length
   T_udp_len1 = &H38

   '41 is checksum
   '42 is checksum


   Restore Ntp_reqdata
   For Ntp_b = 1 To 6
      Read T_udp_data(ntp_b)
   Next Ntp_b
   Call Tcp_ip_header_checksum
   Call Udp_checksum
   Ntp_pcktlen = T_udp_len0 * 256
   Ntp_pcktlen = Ntp_pcktlen + T_udp_len1
   Ntp_pcktlen = Ntp_pcktlen + 34
   #if Ntp_debug = 1
   '   Tcp_pcktlen = Ntp_pcktlen
      Print "NTP Query Packet Sendout"
      'Gosub Print_buffer
   #endif
   Call Enc28j60packetsend(ntp_pcktlen)
   Incr Ntp_ready


End Sub



' Routine to convert the LONG from the NTP-server in to date and time

Sub Ntp_response

   Tcp_bytes(1) = T_ntp_tx_timestamp3                       't_udp_data(16),field ntpreftime
   Tcp_bytes(2) = T_ntp_tx_timestamp2
   Tcp_bytes(3) = T_ntp_tx_timestamp1
   Tcp_bytes(4) = T_ntp_tx_timestamp0
   'Swap B4(1) , B4(4) : Swap B4(2) , B4(3)
   'ntp_l1 now with seconds after 1900 (syssec)
   'define GETTIMEOFDAY_TO_NTP_OFFSET 2208988800UL
   Ntp_local = Tcp_long + 1139293696
   Ntp_local = Ntp_local + My_ntpoff                        ' offset UTC + 1 hour
   Ntp_ready = 255
   Call Ntp_dst_correction
   #if Ntp_debug = 1
      Print "NTP Answer Packet received"
      Gosub Print_buffer
    Print "NTP-Date : " ; Date(ntp_local)
    Print "NTP-Time : " ; Time(ntp_local)
   #endif


End Sub

Sub Ntp_dst_correction
'Dont change order of time and date variables !!! This order is required for Date/Time functions used.
'this routine is orginated by framuel
Local Second As Byte
Local Minute As Byte
Local Hour As Byte
Local Day As Byte
Local Month As Byte
Local Year As Byte
Local Dow As Byte                                           'Day of week

   Day = Date(ntp_local)                                    'set 3 variables: Day, Month, Year, so Year contains now current year
'DST starts at the last sunday of March, so let's see what weekday the 1st of April is
   Month = 4
   Day = 1
   Hour = 2
   Minute = 0
   Second = 0
   Dow = Dayofweek(day)                                     '0 = Monday to 6 = Sunday
   Day = 31 - Dow                                           'Now count back the days until last sunday
   Month = 3                                                'and set month to March
   If Ntp_local >= Syssec(second) Then
       'DST ends at the last sunday of October, so let's see what weekday the 1st of November is
       Day = 1
       Month = 11
       Dow = Dayofweek(day)                                 '0 = Monday to 6 = Sunday
       Day = 31 - Dow                                       'Now count back the days until last sunday
       Month = 10                                           'and set month to October
       If Ntp_local < Syssec(second) Then
          Ntp_local = Ntp_local + 3600                      'subtract one hour
          #if Ntp_debug = 1
             Print "It's summertime ... one hour added"
          #endif
       End If
   End If

End Sub

Ntp_reqdata:
Data &HD9 , &H00 , &H0A , &HFA , &H01 , &H04