'
'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
' modified Thomas Dressler 2009
'--------------------------------------------------------------
'routines for basic networking

'swap bytes of word for bigendian/little endian conversion
Function Tcp_w2w(byval W As Word) As Word
Tcp_word = W
Swap Tcp_byteh , Tcp_bytel
Tcp_w2w = Tcp_word
End Function


'check if new data announced
Checkfor_netdata:
If Tcp_data_present = 1 Then                                ' set by ISR_INT2
   Call Enc28j60writecontrolregbyte(en_eie , &H40)          'disable the ENC28J60 int PIN

      'double check!
   'errata says that PKTIF does not work as it should
   'check packetcount too:
      Call Enc28j60readcontrolregbyte(en_epktcnt)
      En_pkts = 0
      While En_data_byte > 0
         Call Tcp_clearbuff

         Call Enc28j60packetreceive                         'receive the packet

         Call Tcp_handle_packet
         Incr En_pkts
         Call Enc28j60readcontrolregbyte(en_epktcnt)
      Wend                                                  'last packet in en28j20-buffer handled?

      If En_pkts > 0 Then
         #if Tcp_debug = 1
         Print "handled " ; En_pkts ; " packets"
         #endif
         Tcp_data_present = 0
      End If
      Call Enc28j60writecontrolregbyte(en_eie , &HC0)       'enable the ENC28J60 int PIN
End If
Return

'clear tcp buffer
Sub Tcp_clearbuff
  For Tcp_w = 1 To Max_framelen
   Tcp_buffer(tcp_w) = 0
  Next Tcp_w

End Sub

                                                  'for compiler


'main packet handler
Sub Tcp_handle_packet
 'Handle the packet

    If T_enetpackettype = T_packet_arp Then
    'Arp packet received
    #if Tcp_debug = 1
            Print "ARP Packet"
    #endif
            If T_arp_op1 = T_arp_req Then
               'ARP request
               If T_arp_tipaddr = My_ip Then
                        Call Tcp_arpreply
               End If
            Elseif T_arp_op1 = T_arp_resp Then              'ARP rresponse

               If T_arp_tipaddr = My_ip Then
                  Gosub Tcp_arpresponse
               End If

            End If

    Elseif T_enetpackettype = T_packet_ip Then              'Type:IP
    'IP Packet received, need more checks
          #if Tcp_debug = 1
            Print "Got IPPacket ";
            Print "Source IP  " ; T_ip_srcaddr0 ; "." ; T_ip_srcaddr1 ; "." ; T_ip_srcaddr2 ; "." ; T_ip_srcaddr3
            Print "Dest IP  " ; T_ip_destaddr0 ; "." ; T_ip_destaddr1 ; "." ; T_ip_destaddr2 ; "." ; T_ip_destaddr3
            Print "Proto:" ; T_ip_proto

            Tcp_w = Tcp_w2w(t_tcp_destport)
            Print "Len: " ; Tcp_pcktlen ; "Port: " ; Tcp_w

          #endif
         'If T_ip_vers_len = T_def_vers_len Then             'We handle only simple IP packets
            'If T_ip_flags= 0 Then                          'We handle only non fragmented packets


              If T_ip_destaddr = My_ip Then                 'Ip packet for us
              'i am the target

                Select Case T_ip_proto

                        Case T_prot_icmp :                  'Protocol:ICMP
                            #if Tcp_debug = 1
                            Print "Proto ICMP"
                            #endif
                           If T_icmp_type = T_icmp_req Then 'ICMP echo request
                             Call Tcp_pingreply
                           End If

                        Case T_prot_udp:                    'Protocol:UDP
                           #if Tcp_debug = 1
                           Print "Proto UDP"
                           #endif
                           Call Udp_receive

                        Case T_prot_tcp:                    'Protocol:TCP
                           #if Tcp_debug = 1
                           Print "Proto TCP"
                           #endif
                           Call Tcp_receive
                End Select

              Elseif T_ip_destaddr3 = 255 Then
              'Ip broadcast (simple check, needs to be replaced whith real bradcast adress check)

              '
                          If T_ip_proto = T_prot_udp Then   'Protocol:UDP Broadcast
                           #if Tcp_debug = 1
                              Print "UDP-Broadcast"
                           #endif
                            Call Udp_receive

                         End If
              #if Tcp_debug = 1
              Else
               'packets for others
               Print "Not me:Dest IP  " ; T_ip_destaddr0 ; "." ; T_ip_destaddr1 ; "." ; T_ip_destaddr2 ; "." ; T_ip_destaddr3

              #endif
             End If


          'End If ' ip flags
         'End If  'ip_vers_len
      #if Tcp_debug = 1
      Else
         Print "Packet type unknown:" ; Hex(t_enetpackettype)
      #endif
     End If


End Sub

'*************** ARP ***************************
'complete arp query, result will be in destmac
Sub Tcp_arpquery
'query for arp mac
Local Arp_loop1 As Byte
Local Arp_loop2 As Byte
Local La As Long
Local Lb As Long

#if Arp_debug = 1
 Print "Call arpquery for " ; Tcp_destip(1) ; "." ; Tcp_destip(2) ; "." ; Tcp_destip(3) ; "." ; Tcp_destip(4)
#endif

La = Tcp_dest_ip And My_mask
Lb = My_ip And My_mask
If La = Lb Then
   'local net, ask for mac
   #if Arp_debug = 1
      Print "Localnet, ask for MAC"
   #endif

   Tcp_destmac(1) = 255

   For Arp_loop1 = 1 To 10
   'resend request every 0,2s , 10 times
      If Tcp_destmac(1) = 255 Then
         Call Tcp_arprequest
         For Arp_loop2 = 1 To 200
            'check answer for 2s
            Waitms 1
            Gosub Checkfor_netdata
            If Arp_ready = 1 then
            'If Tcp_destmac(1) < 255 Then
                  Exit For
            End If
         Next Arp_loop2
      Else
         #if Arp_debug = 1
            Print "Arp answer for " ; Tcp_destip(1) ; "." ; Tcp_destip(2) ; "." ; Tcp_destip(3) ; "." ; Tcp_destip(4)
            Print "MAC= " ; Hex(tcp_destmac(1)) ; "-" ; Hex(tcp_destmac(2)) ; "-" ; Hex(tcp_destmac(3)) ; "-" ; Hex(tcp_destmac(4)) ; "-" ; Hex(tcp_destmac(5)) ; "-" ; Hex(tcp_destmac(6))
         #endif
         Exit For
      End If
      Next Arp_loop1
Else
   'foreign net, use router
   Tcp_b = Memcopy(mygw_mac(1) , Tcp_destmac(1) , 6)
   #if Arp_debug = 1
            Print "Use router as arp answer for " ; Tcp_destip(1) ; "." ; Tcp_destip(2) ; "." ; Tcp_destip(3) ; "." ; Tcp_destip(4)
            Print "MAC= " ; Hex(tcp_destmac(1)) ; "-" ; Hex(tcp_destmac(2)) ; "-" ; Hex(tcp_destmac(3)) ; "-" ; Hex(tcp_destmac(4)) ; "-" ; Hex(tcp_destmac(5)) ; "-" ; Hex(tcp_destmac(6))
   #endif

End If
End Sub

' Routine for the ARP-Reply
Sub Tcp_arpreply
#if Arp_debug = 1
   Print " Call Arpreply"
    Print "Will answer to " ; T_arp_sipaddr0 ; "." ; T_arp_sipaddr1 ; "." ; T_arp_sipaddr2 ; "." ; T_arp_sipaddr3
#endif
   'The original request packet is in the tcp_buffer, we just change some things
   'Swap MAC addresses
   Tcp_dest_ip = T_arp_sipaddr
   Tcp_b = Memcopy(t_arp_src_enetpacket(1) , Tcp_destmac(1) , 6)
   Call Tcp_clearbuff
   Gosub Tcp_ethernet_header
   Gosub Tcp_arp_header
   'Set ARP type from Request to Reply
   T_arp_op1 = T_arp_resp

   'Send the reply packet
   Call Enc28j60packetsend(42)

End Sub


'create and send arp request
Sub Tcp_arprequest
#if Arp_debug = 1
 Print "Call arprequest"
#endif
 Arp_ready = 0
 'defaults all buffer to 0
   Call Tcp_clearbuff
   'destination broadcast
   For Tcp_b = 1 To 6
    Tcp_destmac(tcp_b) = &HFF
   Next Tcp_b

   Gosub Tcp_ethernet_header
   Gosub Tcp_arp_header
'Set ARP type to Request
   T_arp_op1 = T_arp_req

   'Send the request packet
   Call Enc28j60packetsend(arp_packet_len)

End Sub

'********** reused subs **************
'got arp response, copy mac to destmac
Tcp_arpresponse:
#if Arp_debug = 1
 Print "Arpresponse"
#endif
   'arp answer to own request
   Tcp_b = Memcopy(t_arp_src_enetpacket(1) , Tcp_destmac(1) , 6)
   Arp_ready = 1
Return

Tcp_arp_header:
'fillout tcp buffer with common arp specifcs
'protocoll
T_enetpackettype = T_packet_arp                             '0806 ARP
'arp specific
T_arp_hwtype0 = &H00                                        '0001 ethernet
T_arp_hwtype1 = &H01

T_arp_prtype0 = &H08                                        'IP
T_arp_prtype1 = &H0
T_arp_hwlen = 6
T_arp_prlen = 4

   'Copy source MAC to ARP
   Tcp_b = Memcopy(t_enetpacketsrc(1) , T_arp_src_enetpacket(1) , 6)

   'Set source IP to ARP packet pos 29
   T_arp_sipaddr = My_ip

 'Set target IP in ARP packet
   T_arp_tipaddr = Tcp_dest_ip

   'Copy target MAC to ARP
   Tcp_b = Memcopy(tcp_destmac(1) , T_arp_dest_enetpacket(1) , 6)
Return

'create common Ethernet header in buffer
Tcp_ethernet_header:
   Tcp_b = Memcopy(tcp_destmac(1) , T_enetpacketdest(1) , 6)
   Tcp_b = Memcopy(en_mac(1) , T_enetpacketsrc(1) , 6)
   T_enetpackettype = T_packet_ip
Return




' Routine to handle the source/destination address
'
Tcp_ip_answer_header:
   T_ip_destaddr = T_ip_srcaddr
   Tcp_dest_ip = T_ip_srcaddr
   'make ethernet module IP address source address
   T_ip_srcaddr = My_ip
   Tcp_b = Memcopy(t_enetpacketsrc(1) , Tcp_destmac(1) , 6)
   Gosub Tcp_ethernet_header
   'Set source MAC in ethernet frame, pos 7
   Call Tcp_ip_header_checksum
Return



'*****************  TCP-traffic filter ************************
'
Sub Tcp_receive
#if Tcp_debug = 1
 Print "TCP-Received: "
 Print "Source IP  " ; T_ip_srcaddr0 ; "." ; T_ip_srcaddr1 ; "." ; T_ip_srcaddr2 ; "." ; T_ip_srcaddr3
' Print "Tcp_seqnum " ; Hex(tcp_seqnum3) ; " " ; Hex(tcp_seqnum2) ; " " ; Hex(tcp_seqnum1) ; " " ; Hex(tcp_seqnum0)
' Print "Tcp_acknum " ; Hex(tcp_acknum3) ; " " ; Hex(tcp_acknum2) ; " " ; Hex(tcp_acknum1) ; " " ; Hex(tcp_acknum0)
' Print
' Print "++++++++++++++++++++++++"
  Tcp_w = Tcp_w2w(t_tcp_destport)
  Print "Len: " ; Tcp_pcktlen ; "Port: " ; Tcp_w
#endif

   'If Tcp_destporth = 0 Then

      'If Tcp_destportl = 80 Then
         'Call Http
    '  End If
 '         Print ""
    '  If Tcp_destportl = 23 Then
    '     Call Telnet
    '  End If

   'End If
End Sub

' *****************  UDP-traffic filter ********************
'
Sub Udp_receive
#if Tcp_debug = 1

 'Print
 Print "UDP received "
 Print "Source IP  " ; T_ip_srcaddr0 ; "." ; T_ip_srcaddr1 ; "." ; T_ip_srcaddr2 ; "." ; T_ip_srcaddr3;
 Tcp_pcktlen = Tcp_w2w(t_udp_len)
 Tcp_w = Tcp_w2w(t_udp_destport)
 Print "Len: " ; Tcp_pcktlen ; "Port: " ; Tcp_w

 'Gosub Print_buffer

#endif

'ntp stuff
#if Use_ntp = 1
   If T_udp_destport = T_port_ntp Then                      '123 port we use for the request

         Call Ntp_response

      Exit Sub
   End If
#endif
'dhcp stuff ->not working yet
#if Use_dhcp = 1
   If T_udp_destport = T_port_dhcp_client Then              '68 our DHCP port
      If T_udp_srcport = T_port_dhcp_server Then            '67 server DHCP port
         Call Dhcp_response
      End If
      Exit Sub
   End If
#endif

End Sub

' Routine for the Ping-Reply

Sub Tcp_pingreply
#if Tcp_debug = 1
   Print "Call Pingreply"
   Print "Will answer to " ; T_ip_srcaddr0 ; "." ; T_ip_srcaddr1 ; "." ; T_ip_srcaddr2 ; "." ; T_ip_srcaddr3
#endif

   'Local Packetlength As Word
   Tcp_pcktlen = T_ip_pktlen0 * 256
   Tcp_pcktlen = Tcp_pcktlen + T_ip_pktlen1
   'We are going to calculate the checksum till the end of packet (IP length + 14 byte of the ethernet stuff), -1 to get word start
'
   Tcp_pcktlen = Tcp_pcktlen + 13
   'set echo reply
   T_icmp_type = T_icmp_resp
   T_icmp_code = &H00
   'setup the IP-header
   Gosub Tcp_ip_answer_header
   Call Tcp_icmp_checksum
   Tcp_pcktlen = Tcp_pcktlen + 1
   'Send the reply packet
   #if Icmp_debug = 1
   Gosub Print_buffer
   #endif
   Call Enc28j60packetsend(tcp_pcktlen)
End Sub



'******************** Checksum Routines ***************

' Routine to calculate a IP-header checksum
'
Sub Tcp_ip_header_checksum
  Local Ip_checksum16 As Word
  Local Ip_header_length As Byte
  T_ip_hdr_cksum = &H00                                     'Calc starts with chksum=0
  'Calculate IP header length
  Ip_header_length = T_ip_vers_len And &H0F                 'Number of 32 bit words
  Ip_header_length = 4 * Ip_header_length                   'Calc number of bytes
  Ip_checksum16 = Tcpchecksum(t_ip_header(1) , Ip_header_length )       'Tcp_buffer(15)
  'Store the checksum value in the packet tcp_buffer
  T_ip_hdr_cksum1 = High(ip_checksum16)
  T_ip_hdr_cksum0 = Low(ip_checksum16)
End Sub


' Routine to calculate a ICMP-checksum
'
Sub Tcp_icmp_checksum
  Local Ip_checksum16 As Word
  Local Ip_data_length As Word

  'Clear the ICMP checksum before starting calculation
  T_icmp_cksum = &H00
  'Calculate the ICMP checksum
  Tcp_byteh = T_ip_pktlen0
  Tcp_bytel = T_ip_pktlen1
  Ip_data_length = Tcp_word - 20
  Ip_checksum16 = Tcpchecksum(t_ip_data(1) , Ip_data_length )       'built-in way
  T_icmp_cksum1 = High(ip_checksum16)
  T_icmp_cksum0 = Low(ip_checksum16)
End Sub



'Tcp-checksum
'
Sub Tcp_checksum
   'Local W1 As Word
   'Local W2 As Word
   Local Val1 As Word
   Local Val2 As Word
   T_tcp_cksum = 0
   Tcp_l = 0
   Gosub Tcp_header_chksum
   'resultat in tcp_l
   Tcp_byteh = T_udp_len0
   Tcp_bytel = T_udp_len1
   Tcp_l = Tcp_l + Tcp_word

   'Tempwordh = T_ip_pktlen0
   'Tempwordl = T_ip_pktlen1
   'I_chksum32 = I_chksum32 + Tempword
   'W2 = T_ip_vers_len And &H0F
   'W2 = W2 * 4
   'I_chksum32 = I_chksum32 - W2
   Tcp_l = Tcp_l - 20                                       '20bytes header von länge abziehen
   Tcp_word = Tcp_word - 20
   Val2 = Highw(tcp_l)
   Val1 = Tcp_l
   Tcp_word = Tcpchecksum(t_ip_data(1) , Tcp_word , Val2 , Val1)
   T_tcp_cksuml = High(tcp_word)
   T_tcp_cksumh = Low(tcp_word)
End Sub


' Routine to calculate the IP-checkum
'
Sub Udp_checksum
   Local Val1 As Word
   Local Val2 As Word
   T_udp_chksum = &H00
   Tcp_l = 0
  Gosub Tcp_header_chksum
   'resultat in tcp_l
   'packet length
   Tcp_byteh = T_udp_len0
   Tcp_bytel = T_udp_len1
   Tcp_l = Tcp_l + Tcp_word

   'Result16h = T_udp_len0
   'Result16l = T_udp_len1

   Val2 = Highw(tcp_l)
   Val1 = Tcp_l

   Tcp_w = Tcpchecksum(t_ip_data(1) , Tcp_word , Val1 , Val2)
   T_udp_chksum = Tcp_w
   'T_udp_chksum0 = High(tcp_word)
   'T_udp_chksum1 = Low(tcp_word)
End Sub

Tcp_header_chksum:
   'checksum Pseudo TCP header (src,dest+proto)

   Tcp_byteh = T_ip_srcaddr0
   Tcp_bytel = T_ip_srcaddr1
   Tcp_l = Tcp_l + Tcp_word
   Tcp_byteh = T_ip_srcaddr2
   Tcp_bytel = T_ip_srcaddr3
   Tcp_l = Tcp_l + Tcp_word

   Tcp_byteh = T_ip_destaddr0
   Tcp_bytel = T_ip_destaddr1
   Tcp_l = Tcp_l + Tcp_word
   Tcp_byteh = T_ip_destaddr2
   Tcp_bytel = T_ip_destaddr3
   Tcp_l = Tcp_l + Tcp_word
   'proto
   Tcp_l = Tcp_l + T_ip_proto

Return
