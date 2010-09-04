
''--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
' modified Thomas Dressler 2009
'--------------------------------------------------------------
'
' Declarations and Subroutines for ENC28j60
' modified from enj28j60.inc

Declare Sub Enc28j60_reset
Declare Sub Enc28j60_setextclock
Declare Sub Enc28j60_init
Declare Sub Enc28j60_version
Declare Sub Enc28j60readcontrolregbyte(byval En_register As Byte)
Declare Sub Enc28j60writecontrolregbyte(byval En_register As Byte , Byval En_b As Byte)
Declare Sub Enc28j60selectbank(byval En_b As Byte)
Declare Sub Enc28j60bitfield_set(byval En_register As Byte , Byval En_b As Byte)
Declare Sub Enc28j60bitfield_clear(byval En_register As Byte , Byval En_b As Byte)
Declare Sub Enc28j60readphyword(byval En_phyregister As Byte)
Declare Sub Enc28j60writephyword(byval En_phyregister As Byte , Byval En_w As Word)
Declare Sub Enc28j60packetsend(byval En_len As Word)
Declare Sub Enc28j60packetreceive
Declare Sub Enc28j60poll

Dim En_a(5) As Byte
Dim En_mac(6) As Byte

Dim En_data_byte As Byte
Dim En_data_word As Word
Dim En_nextpacketptr As Word
Dim En_pcktlen As Word
Dim En_pkts As Word

#if Varexist( "SPIF0")
 Spif Alias Spif0
#endif                                                      'for mega644



'declared outside:
'const max_framesize=512
'encAlias Portb.4                                   'CS pin of the ENC28J60
'Config Enc28j60_cs = Output



' ENC28J60 Control Registers
' Control register definitions are a combination of address,
' bank number, and Ethernet/MAC/PHY indicator bits.
' - Register address (bits 0-4)
' - Bank number  (bits 7-6)
' - MAC/PHY indicator (bit 5)

'All-bank registers
Const En_eie = &H1B
Const En_eir = &H1C
Const En_estat = &H1D
Const En_econ2 = &H1E
Const En_econ1 = &H1F

'for bank selection
Const En_bank0 = &B00_000000
Const En_bank1 = &B01_000000
Const En_bank2 = &B10_000000
Const En_bank3 = &B11_000000

'MAC/PHY indicator
Const En_macphy = &B00_1_00000

'Bank 0 registers
Const En_erdptl = &H00 Or En_bank0
Const En_erdpth = &H01 Or En_bank0
Const En_ewrptl = &H02 Or En_bank0
Const En_ewrpth = &H03 Or En_bank0
Const En_etxstl = &H04 Or En_bank0
Const En_etxsth = &H05 Or En_bank0
Const En_etxndl = &H06 Or En_bank0
Const En_etxndh = &H07 Or En_bank0
Const En_erxstl = &H08 Or En_bank0
Const En_erxsth = &H09 Or En_bank0
Const En_erxndl = &H0A Or En_bank0
Const En_erxndh = &H0B Or En_bank0
Const En_erxrdptl = &H0C Or En_bank0
Const En_erxrdpth = &H0D Or En_bank0
Const En_erxwrptl = &H0E Or En_bank0
Const En_erxwrpth = &H0F Or En_bank0
Const En_edmastl = &H10 Or En_bank0
Const En_edmasth = &H11 Or En_bank0
Const En_edmandl = &H12 Or En_bank0
Const En_edmandh = &H13 Or En_bank0
Const En_edmadstl = &H14 Or En_bank0
Const En_edmadsth = &H15 Or En_bank0
Const En_edmacsl = &H16 Or En_bank0
Const En_edmacsh = &H17 Or En_bank0

' Bank 1 registers
Const En_eht0 = &H00 Or En_bank1
Const En_eht1 = &H01 Or En_bank1
Const En_eht2 = &H02 Or En_bank1
Const En_eht3 = &H03 Or En_bank1
Const En_eht4 = &H04 Or En_bank1
Const En_eht5 = &H05 Or En_bank1
Const En_eht6 = &H06 Or En_bank1
Const En_eht7 = &H07 Or En_bank1
Const En_epmm0 = &H08 Or En_bank1
Const En_epmm1 = &H09 Or En_bank1
Const En_epmm2 = &H0A Or En_bank1
Const En_epmm3 = &H0B Or En_bank1
Const En_epmm4 = &H0C Or En_bank1
Const En_epmm5 = &H0D Or En_bank1
Const En_epmm6 = &H0E Or En_bank1
Const En_epmm7 = &H0F Or En_bank1
Const En_epmcsl = &H10 Or En_bank1
Const En_epmcsh = &H11 Or En_bank1
Const En_epmol = &H14 Or En_bank1
Const En_epmoh = &H15 Or En_bank1
Const En_ewolie = &H16 Or En_bank1
Const En_ewolir = &H17 Or En_bank1
Const En_erxfcon = &H18 Or En_bank1
Const En_epktcnt = &H19 Or En_bank1

' Bank 2 registers
Const En_macon1 = &H00 Or En_bank2 Or En_macphy
Const En_macon2 = &H01 Or En_bank2 Or En_macphy
Const En_macon3 = &H02 Or En_bank2 Or En_macphy
Const En_macon4 = &H03 Or En_bank2 Or En_macphy
Const En_mabbipg = &H04 Or En_bank2 Or En_macphy
Const En_maipgl = &H06 Or En_bank2 Or En_macphy
Const En_maipgh = &H07 Or En_bank2 Or En_macphy
Const En_maclcon1 = &H08 Or En_bank2 Or En_macphy
Const En_maclcon2 = &H09 Or En_bank2 Or En_macphy
Const En_mamxfll = &H0A Or En_bank2 Or En_macphy
Const En_mamxflh = &H0B Or En_bank2 Or En_macphy
Const En_maphsup = &H0D Or En_bank2 Or En_macphy
Const En_micon = &H11 Or En_bank2 Or En_macphy
Const En_micmd = &H12 Or En_bank2 Or En_macphy
Const En_miregadr = &H14 Or En_bank2 Or En_macphy
Const En_miwrl = &H16 Or En_bank2 Or En_macphy
Const En_miwrh = &H17 Or En_bank2 Or En_macphy
Const En_mirdl = &H18 Or En_bank2 Or En_macphy
Const En_mirdh = &H19 Or En_bank2 Or En_macphy

' Bank 3 registers
Const En_maadr1 = &H00 Or En_bank3 Or En_macphy
Const En_maadr0 = &H01 Or En_bank3 Or En_macphy
Const En_maadr3 = &H02 Or En_bank3 Or En_macphy
Const En_maadr2 = &H03 Or En_bank3 Or En_macphy
Const En_maadr5 = &H04 Or En_bank3 Or En_macphy
Const En_maadr4 = &H05 Or En_bank3 Or En_macphy
Const En_ebstsd = &H06 Or En_bank3
Const En_ebstcon = &H07 Or En_bank3
Const En_ebstcsl = &H08 Or En_bank3
Const En_ebstcsh = &H09 Or En_bank3
Const En_mistat = &H0A Or En_bank3 Or En_macphy             'checken of goed is
Const En_erevid = &H12 Or En_bank3
Const En_ecocon = &H15 Or En_bank3
Const En_eflocon = &H17 Or En_bank3
Const En_epausl = &H18 Or En_bank3
Const En_epaush = &H19 Or En_bank3

' PHY registers
Const En_phcon1 = &H00
Const En_phstat1 = &H01
Const En_phhid1 = &H02
Const En_phhid2 = &H03
Const En_phcon2 = &H10
Const En_phstat2 = &H11
Const En_phie = &H12
Const En_phir = &H13
Const En_phlcon = &H14


' ENC28J60 EIR Register Bit Definitions
'--
Const En_eir_pktif = 6
Const En_eir_dmaif = 5
Const En_eir_linkif = 4
Const En_eir_txif = 3
Const En_eir_wolif = 2
Const En_eir_txerif = 1
Const En_eir_rxerif = 0

' ENC28J60 ESTAT Register Bit Definitions
Const En_estat_int = 7
'Const Estat_bufer = 6
'--
Const En_estat_latecol = 4
'--
Const En_estat_rxbusy = 2
Const En_estat_txabrt = 1
Const En_estat_clkrdy = 0


' ENC28J60 EIE Register Bit Definitions
Const En_eie_intie = 7
Const En_eie_pktie = 6
Const En_eie_dmaie = 5
Const En_eie_linkie = 4
Const En_eie_txie = 3
Const En_eie_wolie = 2
Const En_eie_txerie = 1
Const En_eie_rxerie = 0


' ENC28J60 ECON2 Register Bit Definitions
Const En_econ2_autoinc = 7
Const En_econ2_pktdec = 6
Const En_econ2_pwrsv = 5
'--
Const En_econ2_vrps = 3
'--
'--
'--

' ENC28J60 ECON1 Register Bit Definitions
Const En_econ1_txrst = 7
Const En_econ1_rxrst = 6
Const En_econ1_dmast = 5
Const En_econ1_csumen = 4
Const En_econ1_txrts = 3
Const En_econ1_rxen = 2
Const En_econ1_bsel1 = 1
Const En_econ1_bsel0 = 0

' ENC28J60 MACON1 Register Bit Definitions
Const En_macon1_loopbk = 4                                  '?? reserved (&H10)
Const En_macon1_txpaus = 3
Const En_macon1_rxpaus = 2
Const En_macon1_passall = 1
Const En_macon1_marxen = 0

' ENC28J60 MACON2 Register Bit Definitions
Const En_macon2_marst = 7
Const En_macon2_rndrst = 6
'--
'--
Const En_macon2_marxrst = 4
Const En_macon2_rfunrst = 2
Const En_macon2_matxrst = 1
Const En_macon2_tfunrst = 0

' ENC28J60 MACON3 Register Bit Definitions
Const En_macon3_padcfg2 = 7
Const En_macon3_padcfg1 = 6
Const En_macon3_padcfg0 = 5
Const En_macon3_txcrcen = 4
Const En_macon3_phdrlen = 3
Const En_macon3_hfrmlen = 2
Const En_macon3_frmlnen = 1
Const En_macon3_fuldpx = 0

' ENC28J60 MICMD Register Bit Definitions
Const En_micmd_miiscan = 1
Const En_micmd_miird = 0

' ENC28J60 MISTAT Register Bit Definitions
Const En_mistat_nvalid = 2
Const En_mistat_scan = 1
Const En_mistat_busy = 0

' ENC28J60 PHY PHCON1 Register Bit Definitions
Const En_phcon1_prst = &H8000
Const En_phcon1_ploopbk = &H4000
Const En_phcon1_ppwrsv = &H0800
Const En_phcon1_pdpxmd = &H0100

' ENC28J60 PHY PHSTAT1 Register Bit Definitions
Const En_phstat1_pfdpx = &H1000
Const En_phstat1_phdpx = &H0800
Const En_phstat1_llstat = &H0004
Const En_phstat1_jbstat = &H0002

' ENC28J60 PHY PHCON2 Register Bit Definitions
Const En_phcon2_frclink = &H4000
Const En_phcon2_txdis = &H2000
Const En_phcon2_jabber = &H0400
Const En_phcon2_hdldis = &H0100

' ENC28J60 Packet Control Byte Bit Definitions
Const En_pktctrl_phugeen = 3
Const En_pktctrl_ppaden = 2
Const En_pktctrl_pcrcen = 1
Const En_pktctrl_poverride = 0

' SPI operation codes
'Const en_Enc28j60_read_ctrl_reg = &H00
Const En_enc28j60_read_buf_mem = &H3A
'Const en_Enc28j60_write_ctrl_reg = &H40
Const En_enc28j60_write_buf_mem = &H7A
'Const en_Enc28j60_bit_field_set = &H80
'Const en_Enc28j60_bit_field_clr = &HA0
Const En_enc28j60_soft_reset = &HFF

' buffer boundaries applied to internal 8K ram
' entire available packet buffer space is allocated

Const En_txstart_init = &H0000                              ' start TX buffer at 0
Const En_txstop_init = &H05FF                               ' give TX buffer space for one full ethernet frame (~1500 bytes)
Const En_rxstart_init = &H0600                              ' eceive buffer gets the rest
Const En_rxstop_init = &H1FFF                               '

'ENC28J60 ETHERNET RECEIVE FILTER CONTROL REGISTER

Const En_erxfcon_ucen = 7                                   'default 1 - Unicast Filter Enable bit
Const En_erxfcon_andor = 6                                  'default 0
Const En_erxfcon_crcen = 5                                  'default 1
Const En_erxfcon_pmen = 4                                   'default 0 - Pattern Match Filter Enable bit
Const En_erxfcon_mpen = 3                                   'default 0 - Magic Packet Filter Enable bit
Const En_erxfcon_hten = 2                                   'default 0 - Hash Table Filter Enable bit
Const En_erxfcon_mcen = 1                                   'default 0 - Multicast Filter Enable bit
Const En_erxfcon_bcen = 0                                   'default 1 - Broadcast Filter Enable bit