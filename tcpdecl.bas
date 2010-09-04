'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
' modified Thomas Dressler 2009
'--------------------------------------------------------------

'**************************************  debugging   ************************************************

Const Tcp_debug = 0                                         '0 = No Debug putput to serial console                                                             '1 = Debug output to serial console
Const Arp_debug = 0
Const Icmp_debug = 0
Const Tcp_packetdump = 0


'*** Definitions *****
'minlen with dhcp=576, without only arp+ntp=128
Const Max_framelen = 576                                    'max. Länge = 1518, davon gehen noch 58 für Header etc. weg

Const T_packet_ip = &H0008                                  'packet type IP
Const T_packet_arp = &H0608                                 'packet typ ARP
Const T_prot_udp = &H11                                     'protocol typ udp
Const T_prot_icmp = &H01                                    'protokol typ icmp
Const T_prot_tcp = &H06                                     'protokol TYP tcp
Const T_arp_req = &H01                                      'arp request
Const T_arp_resp = &H02                                     'arp response
Const T_icmp_req = &H08
Const T_icmp_resp = &H00
Const T_port_ntp = &H7B00                                   ' port 123
Const T_port_dhcp_client = &H4400                           'port 68 DHCP Client Port
Const T_port_dhcp_server = &H4300                           'port 67 DHCP Server Port
Const T_def_ttl = &H80                                      '128
Const T_def_tos = 0                                         'no service flgas
Const T_def_flags = 0                                       'no flags, unfragmented
Const T_def_offset = 0                                      'no offset
Const T_def_vers_len = &H45                                 't_ip_vers_len standard

Const Arp_packet_len = 42
Const T_broadcast = 255
Const Max_iplen = Max_framelen - 40
Const Max_udplen = Max_framelen - 48
Const Max_ippacket = Max_framelen - 20
Const Max_tcp_len = Max_framelen - 60


'************* Sub Declarations *****************

Declare Sub Tcp_clearbuff
Declare Function Tcp_w2w(byval W As Word) As Word
Declare Sub Tcp_arpreply
Declare Sub Tcp_arprequest
Declare Sub Tcp_arpquery

Declare Sub Tcp_pingreply
Declare Sub Tcp_setip_id
Declare Sub Udp_receive
Declare Sub Udp_checksum
Declare Sub Tcp_receive

Declare Sub Tcp_ip_header_checksum
Declare Sub Tcp_icmp_checksum
Declare Sub Tcp_checksum
Declare Sub Tcp_handle_packet

'****** Variables

'Buffer
Dim Tcp_buffer(max_framelen) As Byte

'local Data

Dim Myip(4) As Byte
Dim My_ip As Long At Myip Overlay

Dim Mygw(4) As Byte
Dim Mygw_ip As Long At Mygw Overlay
Dim Mygw_mac(6) As Byte

Dim Mymask(4) As Byte
Dim My_mask As Long At Mymask Overlay

'for DNS-routine
Dim Mydns(4) As Byte
Dim Mydns_ip As Long At Mydns Overlay
Dim Mydns_name As String * 16





'arp and header handling
Dim Tcp_destmac(6) As Byte
Dim Tcp_destip(4) As Byte
Dim Tcp_dest_ip As Long At Tcp_destip Overlay

Dim Arp_ready As Bit


'Global DIM's


'Dim Tcp_ip_id As Word
Dim Tcp_data_present As Bit                                 'used in ISR
Dim Tcp_pcktlen As Word
Dim Tcp_b As Byte
Dim Tcp_w As Word
Dim Tcp_l As Long
'multi overlay
Dim Tcp_bytes(4) As Byte
Dim Tcp_long As Long At Tcp_bytes Overlay
Dim Tcp_word As Word At Tcp_bytes Overlay
Dim Tcp_wordl As Word At Tcp_bytes Overlay
Dim Tcp_wordh As Word At Tcp_bytes + 2 Overlay
Dim Tcp_bytel As Byte At Tcp_bytes Overlay
Dim Tcp_byteh As Byte At Tcp_bytes + 1 Overlay



'********** TCP Buffer descriptions *********************

'Ethernet packet destination
Dim T_enetpacketdest(6) As Byte At Tcp_buffer Overlay
Dim T_enetpacketdest0 As Byte At Tcp_buffer Overlay
Dim T_enetpacketdest1 As Byte At Tcp_buffer + &H01 Overlay
Dim T_enetpacketdest2 As Byte At Tcp_buffer + &H02 Overlay
Dim T_enetpacketdest3 As Byte At Tcp_buffer + &H03 Overlay
Dim T_enetpacketdest4 As Byte At Tcp_buffer + &H04 Overlay
Dim T_enetpacketdest5 As Byte At Tcp_buffer + &H05 Overlay
'Ethernet packet source
Dim T_enetpacketsrc(6) As Byte At Tcp_buffer + &H06 Overlay
Dim T_enetpacketsrc0 As Byte At Tcp_buffer + &H06 Overlay
Dim T_enetpacketsrc1 As Byte At Tcp_buffer + &H07 Overlay
Dim T_enetpacketsrc2 As Byte At Tcp_buffer + &H08 Overlay
Dim T_enetpacketsrc3 As Byte At Tcp_buffer + &H09 Overlay
Dim T_enetpacketsrc4 As Byte At Tcp_buffer + &H0A Overlay
Dim T_enetpacketsrc5 As Byte At Tcp_buffer + &H0B Overlay
'Ethernet packet type
Dim T_enetpackettype As Word At Tcp_buffer + &H0C Overlay
Dim T_enetpackettype0 As Byte At Tcp_buffer + &H0C Overlay
Dim T_enetpackettype1 As Byte At Tcp_buffer + &H0D Overlay


Dim T_ip_packet(max_ippacket) As Byte At Tcp_buffer + &H0E Overlay
'tcp header=+14
Dim T_ip_header(20) As Byte At Tcp_buffer + &H0E Overlay
'IP header layout IP version and header length
Dim T_ip_vers_len As Byte At Tcp_buffer + &H0E Overlay      '&H45=version4,5*4Bytelen=20
Dim T_ip_tos As Byte At Tcp_buffer + &H0F Overlay
'tcp_buffer length
Dim T_ip_pktlen As Word At Tcp_buffer + &H10 Overlay
Dim T_ip_pktlen0 As Byte At Tcp_buffer + &H10 Overlay       'Byte0->1?
Dim T_ip_pktlen1 As Byte At Tcp_buffer + &H11 Overlay       'Byte1->0?

Dim T_ip_id As Byte At Tcp_buffer + &H12 Overlay
Dim T_ip_id0 As Byte At Tcp_buffer + &H12 Overlay
Dim T_ip_id1 As Byte At Tcp_buffer + &H13 Overlay

Dim T_ip_flags As Byte At Tcp_buffer + &H14 Overlay
Dim T_ip_offset As Byte At Tcp_buffer + &H15 Overlay
Dim T_ip_ttl As Byte At Tcp_buffer + &H16 Overlay

'protocol (ICMP=1, TCP=6, UDP=17)
Dim T_ip_proto As Byte At Tcp_buffer + &H17 Overlay

'header checksum
Dim T_ip_hdr_cksum0 As Byte At Tcp_buffer + &H18 Overlay
Dim T_ip_hdr_cksum1 As Byte At Tcp_buffer + &H19 Overlay
Dim T_ip_hdr_cksum As Word At Tcp_buffer + &H18 Overlay


'start of TCP  pseudo header
'IP address of source
Dim T_ip_srcaddr As Long At Tcp_buffer + &H1A Overlay
Dim T_ip_srcaddr_b(4) As Byte At Tcp_buffer + &H1E Overlay
Dim T_ip_srcaddr0 As Byte At Tcp_buffer + &H1A Overlay
Dim T_ip_srcaddr1 As Byte At Tcp_buffer + &H1B Overlay
Dim T_ip_srcaddr2 As Byte At Tcp_buffer + &H1C Overlay
Dim T_ip_srcaddr3 As Byte At Tcp_buffer + &H1D Overlay


'IP address of destination
Dim T_ip_destaddr As Long At Tcp_buffer + &H1E Overlay
Dim T_ip_destaddr_b(4) As Byte At Tcp_buffer + &H1E Overlay
Dim T_ip_destaddr0 As Byte At Tcp_buffer + &H1E Overlay
Dim T_ip_destaddr1 As Byte At Tcp_buffer + &H1F Overlay
Dim T_ip_destaddr2 As Byte At Tcp_buffer + &H20 Overlay
Dim T_ip_destaddr3 As Byte At Tcp_buffer + &H21 Overlay
'IP header end 20bytes

Dim T_ip_data(max_iplen) As Byte At Tcp_buffer + &H22 Overlay
'UDP header=+(34)
Dim T_udp_srcport As Word At Tcp_buffer + &H22 Overlay
Dim T_udp_srcport0 As Byte At Tcp_buffer + &H22 Overlay
Dim T_udp_srcport1 As Byte At Tcp_buffer + &H23 Overlay

Dim T_udp_destport As Word At Tcp_buffer + &H24 Overlay
Dim T_udp_destport0 As Byte At Tcp_buffer + &H24 Overlay
Dim T_udp_destport1 As Byte At Tcp_buffer + &H25 Overlay

Dim T_udp_len As Word At Tcp_buffer + &H26 Overlay
Dim T_udp_len0 As Byte At Tcp_buffer + &H26 Overlay
Dim T_udp_len1 As Byte At Tcp_buffer + &H27 Overlay

Dim T_udp_chksum As Word At Tcp_buffer + &H28 Overlay
Dim T_udp_chksum0 As Byte At Tcp_buffer + &H28 Overlay
Dim T_udp_chksum1 As Byte At Tcp_buffer + &H29 Overlay

'udpdata =+42
Dim T_udp_data(max_udplen) As Byte At Tcp_buffer + &H2A Overlay



'icmp +34
Dim T_icmp_type As Byte At Tcp_buffer + &H22 Overlay
Dim T_icmp_code As Byte At Tcp_buffer + &H23 Overlay
Dim T_icmp_cksum As Word At Tcp_buffer + &H24 Overlay
Dim T_icmp_cksum0 As Byte At Tcp_buffer + &H24 Overlay
Dim T_icmp_cksum1 As Byte At Tcp_buffer + &H25 Overlay


'TCP +34
'start tcp header
Dim T_tcp_srcport As Word At Tcp_buffer + &H22 Overlay
Dim T_tcp_srcporth As Byte At Tcp_buffer + &H22 Overlay
Dim T_tcp_srcportl As Byte At Tcp_buffer + &H23 Overlay

Dim T_tcp_destport As Word At Tcp_buffer + &H24 Overlay
Dim T_tcp_destporth As Byte At Tcp_buffer + &H24 Overlay
Dim T_tcp_destportl As Byte At Tcp_buffer + &H25 Overlay

Dim T_tcp_seqnum As Long At Tcp_buffer + &H26 Overlay
Dim T_tcp_seqnum3 As Byte At Tcp_buffer + &H26 Overlay
Dim T_tcp_seqnum2 As Byte At Tcp_buffer + &H27 Overlay
Dim T_tcp_seqnum1 As Byte At Tcp_buffer + &H28 Overlay
Dim T_tcp_seqnum0 As Byte At Tcp_buffer + &H29 Overlay

Dim T_tcp_acknum As Long At Tcp_buffer + &H2A Overlay
Dim T_tcp_acknum3 As Byte At Tcp_buffer + &H2A Overlay
Dim T_tcp_acknum2 As Byte At Tcp_buffer + &H2B Overlay
Dim T_tcp_acknum1 As Byte At Tcp_buffer + &H2C Overlay
Dim T_tcp_acknum0 As Byte At Tcp_buffer + &H2D Overlay

Dim T_tcp_hdr As Byte At Tcp_buffer + &H2E Overlay
Dim T_tcp_flags As Byte At Tcp_buffer + &H2F Overlay
Dim T_tcp_window As Word At Tcp_buffer + &H30 Overlay
Dim T_tcp_cksumh As Byte At Tcp_buffer + &H32 Overlay
Dim T_tcp_cksuml As Byte At Tcp_buffer + &H33 Overlay
Dim T_tcp_cksum As Word At Tcp_buffer + &H32 Overlay
Dim T_tcp_urgent As Word At Tcp_buffer + &H34 Overlay
'end of tcp header=ipheader+20

'tcp-data= TCP_buffer+54
Dim T_tcp_data(max_tcp_len) As Byte At Tcp_buffer + &H36 Overlay


'Arp
Dim T_arp_hwtype As Word At Tcp_buffer + &H0E Overlay
Dim T_arp_hwtype0 As Byte At Tcp_buffer + &H0E Overlay
Dim T_arp_hwtype1 As Byte At Tcp_buffer + &H0F Overlay
Dim T_arp_prtype As Word At Tcp_buffer + &H10 Overlay
Dim T_arp_prtype0 As Byte At Tcp_buffer + &H10 Overlay
Dim T_arp_prtype1 As Byte At Tcp_buffer + &H11 Overlay
Dim T_arp_hwlen As Byte At Tcp_buffer + &H12 Overlay
Dim T_arp_prlen As Byte At Tcp_buffer + &H13 Overlay
Dim T_arp_op As Word At Tcp_buffer + &H14 Overlay
Dim T_arp_op0 As Byte At Tcp_buffer + &H14 Overlay
Dim T_arp_op1 As Byte At Tcp_buffer + &H15 Overlay
'arp source mac address
Dim T_arp_src_enetpacket(6) As Byte At Tcp_buffer + &H16 Overlay
Dim T_arp_src_enetpacket0 As Byte At Tcp_buffer + &H16 Overlay
Dim T_arp_src_enetpacket1 As Byte At Tcp_buffer + &H17 Overlay
Dim T_arp_src_enetpacket2 As Byte At Tcp_buffer + &H18 Overlay
Dim T_arp_src_enetpacket3 As Byte At Tcp_buffer + &H19 Overlay
Dim T_arp_src_enetpacket4 As Byte At Tcp_buffer + &H1A Overlay
Dim T_arp_src_enetpacket5 As Byte At Tcp_buffer + &H1B Overlay
'arp source ip address
Dim T_arp_sipaddr As Long At Tcp_buffer + &H1C Overlay
Dim T_arp_sipaddr0 As Byte At Tcp_buffer + &H1C Overlay
Dim T_arp_sipaddr1 As Byte At Tcp_buffer + &H1D Overlay
Dim T_arp_sipaddr2 As Byte At Tcp_buffer + &H1E Overlay
Dim T_arp_sipaddr3 As Byte At Tcp_buffer + &H1F Overlay
'arp dest mac address
Dim T_arp_dest_enetpacket(6) As Byte At Tcp_buffer + &H20 Overlay
Dim T_arp_dest_enetpacket0 As Byte At Tcp_buffer + &H20 Overlay
Dim T_arp_dest_enetpacket1 As Byte At Tcp_buffer + &H21 Overlay
Dim T_arp_dest_enetpacket2 As Byte At Tcp_buffer + &H22 Overlay
Dim T_arp_dest_enetpacket3 As Byte At Tcp_buffer + &H23 Overlay
Dim T_arp_dest_enetpacket4 As Byte At Tcp_buffer + &H24 Overlay
Dim T_arp_dest_enetpacket5 As Byte At Tcp_buffer + &H25 Overlay

'arp target IP address
Dim T_arp_tipaddr As Long At Tcp_buffer + &H26 Overlay
Dim T_arp_tipaddr0 As Byte At Tcp_buffer + &H26 Overlay
Dim T_arp_tipaddr1 As Byte At Tcp_buffer + &H27 Overlay
Dim T_arp_tipaddr2 As Byte At Tcp_buffer + &H28 Overlay
Dim T_arp_tipaddr3 As Byte At Tcp_buffer + &H29 Overlay








