' routine to receive DHCP information from the DHCP-server
'
'
'
'
'*******************************  DHCP-discover  *******************************

Sub Dhcp_discover

   Local Dhcp_len As Byte
   Local Dhcp_b As Byte

   Gosub Dhcp_header
   T_udp_len0 = &H01                                        'length
   T_udp_len1 = &H02

   'DHCP
   T_dhcp_op = &H01                                         'Dhcp_pack_request
   Dhcp_xid = Syssec()                                      'new transaction id based on s
   T_dhcp_xid = Dhcp_xid

   Restore Dhcp_disc_options

   For Tcp_b = 1 To Dhcp_len
      Read Dhcp_b
      T_dhcp_options(tcp_b) = Dhcp_b                        'request for subnetmask, router and dns
   Next Tcp_b

   Call Tcp_ip_header_checksum
   Call Udp_checksum
   Tcp_pcktlen = T_udp_len0 * 256
   Tcp_pcktlen = Tcp_pcktlen + T_udp_len1
   Tcp_pcktlen = Tcp_pcktlen + 34
   Call Enc28j60packetsend(tcp_pcktlen)

End Sub

'*************************** DHCP-packet filter ********************************

Sub Dhcp_response


  If T_dhcp_op = &H02 Then                                  'boot reply
     If T_dhcp_xid = Dhcp_xid Then                          'my transaction ID
                  If T_dhcp_options(1) = 53 Then            'options  53 DHCP msg type
                     'If Tcp_buffer(284) = &H01 Then
                     Select Case T_dhcp_options(3)
                        Case Dhcpoffer:                     'Dhcp_offer
                           Call Dhcp_request
                        Case Dhcpack:                       'Dhcp_ACK
                           Call Dhcp_lease
                        #if Dhcp_debug = 1
                        Case Else
                            Print "unknown dhcp option"
                        #endif
                      End Select
                     'End If
                  End If
     End If
  End If

End Sub


'******************************  DHCP-request  *********************************




Sub Dhcp_request

  Local Dhcp_word As Word
  Local Dhcp_len As Byte
   Local Dhcp_b As Byte

  'copy suggested ip
  Tcp_l = T_dhcp_yiaddr

  Gosub Dhcp_header

   T_udp_len0 = &H01                                        'length
   T_udp_len1 = &H17

   'dhcp content
   T_dhcp_op = &H01                                         'Dhcp_pack_request

  Restore Dhcp_req_options
   Read Dhcp_len
   For Tcp_b = 1 To Dhcp_len
      Read Dhcp_b
      T_dhcp_options(tcp_b) = Dhcp_b                        'request for subnetmask, router and dns
   Next Tcp_b


  Tcp_b = Memcopy(tcp_bytes(1) , T_dhcp_options(6) , 4)

  T_dhcp_options(10) = &H0C                                 'insert Option 12 -->Hostname
  Tcp_b = Len(dhcp_name)
  T_dhcp_options(11) = Tcp_b
  Dhcp_b = Memcopy(dhcp_name , T_dhcp_options(12) , Tcp_b)
  Tcp_b = Tcp_b + 12
  T_dhcp_options(tcp_b) = &HFF                              'insert end command


  Call Tcp_ip_header_checksum
  Call Udp_checksum
  Tcp_pcktlen = T_udp_len0 * 256
   Tcp_pcktlen = Tcp_pcktlen + T_udp_len1
   Tcp_pcktlen = Tcp_pcktlen + 34
   Call Enc28j60packetsend(tcp_pcktlen)


End Sub


'******************************************************************************

Sub Dhcp_lease

  My_ip = T_dhcp_yiaddr

  Tcp_b = Memcopy(tcp_buffer(92) , Dhcp_lease_time(1) , 6)  'udp+49
  Tcp_b = Memcopy(tcp_buffer(112) , Dhcp_subnetmask(1) , 4)
  Tcp_b = Memcopy(tcp_buffer(118) , Dhcp_broadcast(1) , 4)
  Tcp_b = Memcopy(tcp_buffer(124) , Dhcp_dns(1) , 4)
  Tcp_b = Memcopy(tcp_buffer(128) , Dhcp_domain(1) , 8)
  Tcp_b = Memcopy(tcp_buffer(137) , Dhcp_gateway(1) , 4)

  Dhcp_flag = 1


End Sub

Dhcp_header:
   Call Tcp_clearbuff                                       'Clear the complete buffer

   'Mac-header =============
   For Tcp_b = 1 To 6
    Tcp_destmac(tcp_b) = &HFF
   Next Tcp_b

   Gosub Tcp_ethernet_header
   T_enetpackettype = T_packet_ip                           'ip

   'IP-header ==============

   T_ip_vers_len = T_def_vers_len                           'header length
   T_ip_tos = T_def_tos                                     'Type of service

   T_ip_pktlen0 = High(dhcp_packet_len)                     'total length
   T_ip_pktlen1 = Low(dhcp_packet_len)                      '&H0116

   T_ip_id0 = &H05                                          'IDentification
   T_ip_id1 = &H0D

   T_ip_flags = T_def_flags                                 'flags --> not fragmented

   T_ip_offset = T_def_offset                               'fragment offset

   T_ip_ttl = T_def_ttl                                     'TTL

   T_ip_proto = T_prot_udp                                  'protocol UDP

   '25 is checksum
   '26 is checksum

   T_ip_srcaddr = 0                                         'source address  --> 0.0.0.0

   For Tcp_b = 1 To 4
      T_ip_destaddr_b(tcp_b) = &HFF                         ' cannot use log value, out of range
   Next Tcp_b
   'T_ip_destaddr = &HFFFFFFFF                               'destination IP --> 255.255.255.255

   'source port 68
   T_udp_srcport = T_port_dhcp_client
   'destination port 67 --> ntp server
   T_udp_destport = T_port_dhcp_server

   T_udp_len0 = &H01                                        'length
   T_udp_len1 = &H02

   '41 is checksum
   '42 is checksum

   'DHCP
   T_dhcp_op = &H01                                         'Dhcp_pack_request
   T_dhcp_hwtype = &H01                                     'Dhcp_htype10mb  &H02 --> 100mb
   T_dhcp_maclen = &H06                                     'mac-address length
   T_dhcp_hops = &H00                                       'Dhcp_hops

   'set Xid from timestamp and remember for reply
   T_dhcp_xid = Dhcp_xid
   T_dhcp_flags = &H0080                                    'Broadcast flag

   Tcp_b = Memcopy(en_mac(1) , T_dhcp_mymac(1) , 6)
   T_dhcp_cookie(1) = &H63                                  'DHCP cookie
   T_dhcp_cookie(2) = &H82
   T_dhcp_cookie(3) = &H53
   T_dhcp_cookie(4) = &H63


Return

Dhcp_disc_options:
Data 9
Data 55 , 3 , 1 , 3 , 6,                                    ' option 55 ,len=3, req subnet,router,dns
Data 53 , 1 , 1 ,                                           'option 53 len 1, dhcp discover
Data &HFF                                                   'Terminator
Dhcp_req_options:
Data 5
Data 53 , 1 , 3 ,                                           'option 53 len 1 DHCP_REQUEST
Data 50 , 4 ,                                               'option 50,len 4 ip-adress
