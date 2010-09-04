'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
' modified Thomas Dressler 2009
'--------------------------------------------------------------

'dhcp_decl
Const Dhcp_debug = 1

Declare Sub Dhcp_request
Declare Sub Dhcp_response
Declare Sub Dhcp_lease
Declare Sub Dhcp_discover

'+43
'dhcp type definitions
Dim T_dhcp_op As Byte At T_udp_data Overlay
Dim T_dhcp_hwtype As Byte At T_udp_data + 1 Overlay
Dim T_dhcp_maclen As Byte At T_udp_data + 2 Overlay
Dim T_dhcp_hops As Byte At T_udp_data + 3 Overlay
Dim T_dhcp_xid As Long At T_udp_data + 4 Overlay
Dim T_dhcp_secs As Word At T_udp_data + 8 Overlay
Dim T_dhcp_flags As Word At T_udp_data + 10 Overlay
Dim T_dhcp_ciaddr As Long At T_udp_data + 12 Overlay
Dim T_dhcp_yiaddr As Long At T_udp_data + 16 Overlay
Dim T_dhcp_siaddr As Long At T_udp_data + 20 Overlay
Dim T_dhcp_giaddr As Long At T_udp_data + 24 Overlay
Dim T_dhcp_chaddr(4) As Long At T_udp_data + 28 Overlay
'+71
Dim T_dhcp_mymac(6) As Byte At T_dhcp_chaddr Overlay
'bootp
Dim T_dhcp_sname(64) As Byte At T_udp_data + 44 Overlay
Dim T_dhcp_file(128) As Byte At T_udp_data + 108 Overlay
'+279
Dim T_dhcp_cookie(4) As Byte At T_udp_data + 236 Overlay

Dim T_dhcp_options(312) As Byte At T_udp_data + 240 Overlay



Const Dhcp_op_req = 1
Const Dhcp_op_repl = 2
Const Dhcp_htype_10mb = 1                                   '10mb net-see arp hwtype
Const Dhcp_hlen_mac = 6                                     '6byte Macaddr
Const Dhcp_hops = 0                                         ' for clients =0
Const Dhcp_options_len = 312
Const Dhcp_options_offset = 240
Const Dhcp_packet_len = 300
'
Const Dhcpdiscover = 1
Const Dhcpoffer = 2
Const Dhcprequest = 3
Const Dhcpdecline = 4
Const Dhcpack = 5
Const Dhcpnak = 6
Const Dhcprelease = 7
Const Dhcpinform = 8
Const Dhcpforcerenew = 9
Const Dhcpleasequery = 10
Const Dhcpleaseunassigned = 11
Const Dhcpleaseunknown = 12
Const Dhcpleaseactive = 13

Dim Dhcp_xid As Long
'DHCP

Dim Dhcp_lease_time(6) As Byte
Dim Dhcp_subnetmask(4) As Byte
Dim Dhcp_broadcast(4) As Byte
Dim Dhcp_dns(4) As Byte
Dim Dhcp_domain_name As String * 8
Dim Dhcp_domain(8) As Byte
Dim Dhcp_gateway(4) As Byte
Dim Dhcp_flag As Bit
Dim Dhcp_name As String * 8
'Dim Dhcp_packet_len As Word
