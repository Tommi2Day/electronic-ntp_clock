'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
' modified Thomas Dressler 2009
'--------------------------------------------------------------

'ntp_decl

Const Ntp_debug = 1
Const Ntp_packet_len = 76

Declare Sub Ntp_query
Declare Sub Ntp_request
Declare Sub Ntp_response
Declare Sub Ntp_dst_correction

'ntp
Dim T_ntp_tx_timestamp As Long At T_udp_data + 40 Overlay
Dim T_ntp_tx_timestamp0 As Byte At T_udp_data + 40 Overlay
Dim T_ntp_tx_timestamp1 As Byte At T_udp_data + 41 Overlay
Dim T_ntp_tx_timestamp2 As Byte At T_udp_data + 42 Overlay
Dim T_ntp_tx_timestamp3 As Byte At T_udp_data + 43 Overlay

'for NTP-routine
Dim Myntp(4) As Byte
Dim Myntp_ip As Long At Myntp Overlay
Dim Ntp_local As Long
Dim Ntp_ready As Byte
Dim Myntp_off As Byte