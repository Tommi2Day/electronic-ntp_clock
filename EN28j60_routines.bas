
'--------------------------------------------------------------
' Networking parts based on Code by Ben Zijlstra and Bascom Forum NetIo-Thread
' http://bascom-forum.de/index.php/topic,1781.0.html
' modified Thomas Dressler 2009
'--------------------------------------------------------------

Sub Enc28j60_reset
   Local En_b As Byte
   Enc28j60_cs = 0
   'reset ENC28J60
   En_b = En_enc28j60_soft_reset
   Spiout En_b , 1
   Enc28j60_cs = 1
   Do
   Call Enc28j60readcontrolregbyte(en_estat)
   En_b = En_data_byte.en_estat_clkrdy
   Loop Until En_b = 1
End Sub




Sub Enc28j60_setextclock
   'clock from default divide/4 (6.25 Mhz) to divide/2 (12.5 Mhz)
   Call Enc28j60writecontrolregbyte(en_ecocon , &B00000010)
   Waitms 250
End Sub


Sub Enc28j60_version
   Call Enc28j60selectbank(3)
   'EREVID
   En_a(1) = &B000_10010
   Enc28j60_cs = 0
   Spiout En_a(1) , 1
   Spiin En_a(1) , 2
   Print "Enc28j60-version = " ; En_a(2)
   Enc28j60_cs = 1
End Sub

Sub Enc28j60_init
   Local En_b As Byte
   Call Enc28j60_reset
   Call Enc28j60_setextclock


   'do bank 0 stuff
   'initialize receive tcp_buffer
   '16-bit transfers, must write low byte first
   'set receive tcp_buffer start address
   En_nextpacketptr = En_rxstart_init
   En_b = Low(en_rxstart_init)
   Call Enc28j60writecontrolregbyte(en_erxstl , En_b)
   En_b = High(en_rxstart_init)
    Call Enc28j60writecontrolregbyte(en_erxsth , En_b)

    'set receive tcp_buffer end
    En_b = Low(en_rxstop_init)
    Call Enc28j60writecontrolregbyte(en_erxndl , En_b)
    En_b = High(en_rxstop_init)
    Call Enc28j60writecontrolregbyte(en_erxndh , En_b)

    'set receive pointer address
    En_b = Low(en_rxstart_init)
    Call Enc28j60writecontrolregbyte(en_erxrdptl , En_b)
    En_b = High(en_rxstart_init)
    Call Enc28j60writecontrolregbyte(en_erxrdpth , En_b)


    'set transmit tcp_buffer start
    En_b = Low(en_txstart_init)
    Call Enc28j60writecontrolregbyte(en_etxstl , En_b)
    En_b = High(en_txstart_init)
    Call Enc28j60writecontrolregbyte(en_etxsth , En_b)

    'set receive tcp_buffer end
    En_b = Low(en_txstop_init)
    Call Enc28j60writecontrolregbyte(en_etxndl , En_b)
    En_b = High(en_txstop_init)
    Call Enc28j60writecontrolregbyte(en_etxndh , En_b)


    'setup bank2: (see microchip datasheet p.36)
      '1.) clear the MARST bit in MACON2.
    En_b = 0
    Call Enc28j60writecontrolregbyte(en_macon2 , En_b)

    'do bank 2 stuff
    'enable MAC receive
    En_b = 0
    En_b.en_macon1_marxen = 1
    En_b.en_macon1_txpaus = 1
    En_b.en_macon1_rxpaus = 1
    Call Enc28j60writecontrolregbyte(en_macon1 , En_b)
    '3.) setup MACON3: auto padding of small packets, add crc, enable frame length check:
    'bring MAC out of reset
    'enable automatic padding and CRC operations
    En_b = 0
    En_b.en_macon3_padcfg0 = 1
    En_b.en_macon3_txcrcen = 1
    En_b.en_macon3_frmlnen = 1
    Call Enc28j60writecontrolregbyte(en_macon3 , En_b)


    '4.) don't set up MACON4 (use default)

    '5.) setup maximum framelenght to 1518:
    'set the maximum packet size which the controller will accept
    En_b = Low(max_framelen)
    Call Enc28j60writecontrolregbyte(en_mamxfll , En_b)
    En_b = High(max_framelen)
    Call Enc28j60writecontrolregbyte(en_mamxflh , En_b)

    '6.) set up back-to-back gap: 0x15 for full duplex / 0x12 for half duplex
    'set inter-frame gap (back-to-back)
    Call Enc28j60writecontrolregbyte(en_mabbipg , &H12)

    '//7.) setup non-back-to-back gap: use 0x12
    'set inter-frame gap (non-back-to-back)
    Call Enc28j60writecontrolregbyte(en_maipgl , &H12)

    '//8.) setup non-back-to-back gap high byte: 0x0C for half duplex:
    Call Enc28j60writecontrolregbyte(en_maipgh , &H0C)

    '//9.) don't change MACLCON1+2 / MACLCON2 might be changed for networks with long wires !

   '//setup bank3:
   'bank 3 stuff
   '//10.) programm mac address: BYTE BACKWARD !
    Call Enc28j60writecontrolregbyte(en_maadr5 , En_mac(1))
    Call Enc28j60writecontrolregbyte(en_maadr4 , En_mac(2))
    Call Enc28j60writecontrolregbyte(en_maadr3 , En_mac(3))
    Call Enc28j60writecontrolregbyte(en_maadr2 , En_mac(4))
    Call Enc28j60writecontrolregbyte(en_maadr1 , En_mac(5))
    Call Enc28j60writecontrolregbyte(en_maadr0 , En_mac(6))


    'no loopback of transmitted frames
    Call Enc28j60writephyword(en_phcon2 , En_phcon2_hdldis)
    'switch to bank 0
    Call Enc28j60selectbank(0)
    'enable interrupts

    En_b = 0
    En_b.en_eie_intie = 1
    En_b.en_eie_pktie = 1
    Call Enc28j60bitfield_set(en_eie , En_b)
    'enable interrupt pin
    'Call Enc28j60writecontrolregbyte(en_eie , &HC0)         'enable interrupt pin if a packet is received

    'set filter based on mac-adresse, first we need the checksum over our mac
    'Tcp_word = Tcpchecksum(en_mac(1) , 6)
    'Match filter only on MAC
    'Call Enc28j60writecontrolregbyte(en_epmm0 , &H3F)       'first 6 bytes to match=destmac
    'Call Enc28j60writecontrolregbyte(en_epmm1 , &H00)
    'Call Enc28j60writecontrolregbyte(en_epmcsl , Tcp_bytel) 'low(tcp_word)
    'Call Enc28j60writecontrolregbyte(en_epmcsh , Tcp_byteh) 'high(tcp_word)
    'En_b = 0
    'En_b.en_erxfcon_pmen = 1                                'Pattern Match enable (ARP only)
    'En_b.en_erxfcon_ucen = 1                                'Unicast enable
    'Call Enc28j60bitfield_set(en_erxfcon , En_b)
    'En_b = 0
    'En_b.en_erxfcon_bcen = 0                                '0 = Broadcast enable --> needed for DHCP
    'Call Enc28j60bitfield_clear(en_erxfcon , En_b)
    'CRC check is enabled by default
    'Call Enc28j60writecontrolregbyte(en_erxfcon , 0)        'alternativ: no filter

    'enable packet reception
    En_b = 0
    En_b.en_econ1_rxen = 1
    Call Enc28j60bitfield_set(en_econ1 , En_b)

    'Reset transmit logic
    En_b = 0
    En_b.en_econ1_txrst = 1
    Call Enc28j60bitfield_set(en_econ1 , En_b)
    Call Enc28j60bitfield_clear(en_econ1 , En_b)

    'set up leds: LEDA: link status, LEDB: RX&TX activity, stretch 40ms, stretch enable
    Call Enc28j60writephyword(en_phlcon , &H347A)
    'cave: Table3-3: reset value is 0x3422, do not modify the reserved "3"!!
           'RevA Datasheet page 9: write as '0000', see RevB Datasheet: write 0011!

    Call Enc28j60_version
 End Sub


Sub Enc28j60selectbank(byval En_b As Byte)
   'get ECON1 (BSEL1 en BSEL0)
   En_a(1) = &B000_11111
   Enc28j60_cs = 0
   Spiout En_a(1) , 1
   Spiin En_a(1) , 2
   Enc28j60_cs = 1
   En_a(2) = En_a(2) And &B1111_1100                        'strip bank part
   En_a(2) = En_a(2) Or En_b
   En_a(1) = &B010_11111
   Enc28j60_cs = 0
   Spiout En_a(1) , 2
   Enc28j60_cs = 1
End Sub


Sub Enc28j60writecontrolregbyte(byval En_register As Byte , Byval En_b As Byte)
   Local En_bank As Byte
   En_bank = 0
   If En_register.7 = 1 Then En_bank = 2
   If En_register.6 = 1 Then En_bank = En_bank + 1
   En_register = En_register And &B00011111
   Call Enc28j60selectbank(en_bank)
   En_register.6 = 1                                        'to get a 010_register
   En_a(1) = En_register
   En_a(2) = En_b
   Enc28j60_cs = 0
   Spiout En_a(1) , 2
   Enc28j60_cs = 1
End Sub


Sub Enc28j60readcontrolregbyte(byval En_register As Byte)
   Local En_mcphy As Byte
   Local En_bank As Byte
   En_bank = 0
   En_mcphy = 0
   If En_register.7 = 1 Then En_bank = 2
   If En_register.6 = 1 Then En_bank = En_bank + 1
   If En_register.5 = 1 Then En_mcphy = 1
   En_register = En_register And &B00011111
   Call Enc28j60selectbank(en_bank)
   En_a(1) = En_register
   Enc28j60_cs = 0
   Spiout En_a(1) , 1
   Spiin En_a(1) , 3
   Enc28j60_cs = 1
   'Depending of register (E, MAC, MII) yes or no dummybyte
   If En_mcphy = 1 Then
      En_data_byte = En_a(2)
      Else
      En_data_byte = En_a(1)                                '1.11.9.3  A(1) not A(3)
   End If
End Sub


Sub Enc28j60bitfield_set(byval En_register As Byte , Byval En_b As Byte)
   Local En_bank As Byte
   En_bank = 0
   If En_register.7 = 1 Then En_bank = 2
   If En_register.6 = 1 Then En_bank = En_bank + 1
   En_register = En_register And &B00011111
   Call Enc28j60selectbank(en_bank)
   En_register = En_register Or &B100_00000
   En_a(1) = En_register
   En_a(2) = En_b
   Enc28j60_cs = 0
   Spiout En_a(1) , 2
   Enc28j60_cs = 1
End Sub


Sub Enc28j60bitfield_clear(byval En_register As Byte , Byval En_b As Byte)
   Local En_bank As Byte
   En_bank = 0
   If En_register.7 = 1 Then En_bank = 2
   If En_register.6 = 1 Then En_bank = En_bank + 1
   En_register = En_register And &B00011111
   Call Enc28j60selectbank(en_bank)
   En_register = En_register Or &B101_00000
   En_a(1) = En_register
   En_a(2) = En_b
   Enc28j60_cs = 0
   Spiout En_a(1) , 2
   Enc28j60_cs = 1
End Sub


Sub Enc28j60readphyword(byval En_phyregister As Byte)
   'set the right address and start the register read operation
   Call Enc28j60writecontrolregbyte(en_miregadr , En_phyregister)
   Call Enc28j60writecontrolregbyte(en_micmd , En_micmd_miird)
   'wait until the PHY read complets
   Do
      Call Enc28j60readcontrolregbyte(en_mistat)
   Loop Until En_data_byte.en_mistat_busy = 0
   'quit reading
   Call Enc28j60writecontrolregbyte(en_micmd , 0)
   'get data value
   Call Enc28j60readcontrolregbyte(en_mirdl)
   En_data_word = En_data_byte
   Shift En_data_word , Left , 8
   Call Enc28j60readcontrolregbyte(en_mirdh)
   En_data_word = En_data_word + En_data_byte
End Sub


Sub Enc28j60writephyword(byval En_phyregister As Byte , Byval En_w As Word)
   Local En_temp As Byte
   Local En_value As Byte
   Call Enc28j60readphyword(en_phyregister)

   'set the PHY register address
   Call Enc28j60writecontrolregbyte(en_miregadr , En_phyregister)
   Call Enc28j60readcontrolregbyte(en_miregadr)
   En_temp = En_miregadr
   En_value = Low(en_w)
   Call Enc28j60writecontrolregbyte(en_miwrl , En_value)
   En_value = High(en_w)
   Call Enc28j60writecontrolregbyte(en_miwrh , En_value)
   Do
      Call Enc28j60readcontrolregbyte(en_mistat)
   Loop Until En_data_byte.en_mistat_busy = 0
End Sub

En_spi:

   Do
   Loop Until Spsr.spif = 1                                 'SPI ready
Return

Sub Enc28j60packetreceive

   Local En_word As Word
   Local Rloop As Word
   Local En_value As Byte

   Local En_rxstat As Word

   'set the read pointer to the start of the received packet
   En_value = Low(en_nextpacketptr)
   Call Enc28j60writecontrolregbyte(en_erdptl , En_value)
   En_value = High(en_nextpacketptr)
   Call Enc28j60writecontrolregbyte(en_erdpth , En_value)
    Enc28j60_cs = 0
    'Send Read tcp_buffer Memory command
    Spdr = &H3A
    Gosub En_spi

    'Get the first 6 byte (3 word: Nextpacketptr, Packetlength, Rxstat)
    For Rloop = 1 To 6
          Spdr = &HFF                                       'SPI read
          Gosub En_spi
          Tcp_buffer(rloop) = Spdr
    Next Rloop

    En_nextpacketptr = Tcp_buffer(2) * 256
    En_nextpacketptr = En_nextpacketptr + Tcp_buffer(1)
    En_pcktlen = Tcp_buffer(4) * 256
    En_pcktlen = En_pcktlen + Tcp_buffer(3)
    En_rxstat = Tcp_buffer(6) * 256
    En_rxstat = En_rxstat + Tcp_buffer(5)
    En_pcktlen = En_pcktlen - 4                             'Discard CRC
    'Get the payload


    If En_pcktlen > Max_framelen Then
      En_word = En_pcktlen - Max_framelen
      Print "discard " ; En_word ; " Bytes: Len " ; En_pcktlen
      En_pcktlen = Max_framelen
    End If


      For Rloop = 1 To En_pcktlen                           'why not using spiin????
          Spdr = &HFF                                       'SPI read
          Gosub En_spi
          Tcp_buffer(rloop) = Spdr
      Next Rloop

    Enc28j60_cs = 1
   'move the rx read pointer to the start of the next received packet
   'this frees the memory we just read out
   'ERRATA says we need to check packet pointer:
   En_word = En_nextpacketptr - 1
   If En_word < En_rxstart_init Or En_word > En_rxstop_init Then
      En_value = Low(en_rxstop_init)
      Call Enc28j60writecontrolregbyte(en_erxrdptl , En_value)
      En_value = High(en_rxstop_init)
      Call Enc28j60writecontrolregbyte(en_erxrdpth , En_value)
   Else
      En_value = Low(en_word)
      Call Enc28j60writecontrolregbyte(en_erxrdptl , En_value)
      En_value = High(en_word)
      Call Enc28j60writecontrolregbyte(en_erxrdpth , En_value)
   End If


   'decrement the packet counter indicate we are done with this packet
   En_value = 0
   En_value.en_econ2_pktdec = 1
   Call Enc28j60bitfield_set(en_econ2 , En_value)

#if Tcp_packetdump = 1
   Print "received Packet"
   Gosub Print_buffer
#endif
End Sub


Sub Enc28j60packetsend(byval En_len As Word)
Local Sloop As Word
Local En_value As Byte
   'Load packet into the ENC
   En_pcktlen = En_len
#if Tcp_packetdump = 1
   Print "packet to send "
   Gosub Print_buffer
#endif
   Enc28j60_cs = 0
   Spdr = En_enc28j60_write_buf_mem
   Gosub En_spi
   Spdr = &B000_1110                                        'per packet byte
   Gosub En_spi
   For Sloop = 1 To En_pcktlen
      Spdr = Tcp_buffer(sloop)
      Gosub En_spi
   Next Sloop
   Enc28j60_cs = 1
   'Minimum packet length is 60
   If En_pcktlen < 60 Then En_pcktlen = 60
   'Reset transmit logic
   En_value = 0
   En_value.en_econ1_txrst = 1
   Call Enc28j60bitfield_set(en_econ1 , En_value)
   Call Enc28j60bitfield_clear(en_econ1 , En_value)
   'set the write pointer to start of transmit tcp_buffer area
   En_value = Low(en_txstart_init)
   Call Enc28j60writecontrolregbyte(en_ewrptl , En_value)
   En_value = High(en_txstart_init)
   Call Enc28j60writecontrolregbyte(en_ewrpth , En_value)
   'set the TXND pointer to correspond to the packet size given
   En_value = Low(en_txstart_init)
   En_value = En_value + Low(en_pcktlen)
   Call Enc28j60writecontrolregbyte(en_etxndl , En_value)
   En_value = High(en_txstart_init)
   En_value = En_value + High(en_pcktlen)
   Call Enc28j60writecontrolregbyte(en_etxndh , En_value)
   'write per-packet control byte has been put in the writeroutine
   'send the contents of the transmit tcp_buffer onto the network
   En_value = 0
   En_value.en_econ1_txrts = 1
   Call Enc28j60bitfield_set(en_econ1 , En_value)
End Sub

Print_buffer:
  Tcp_w = 0
   Do

      Print Hex(tcp_buffer(tcp_w + 1)) ; " ";
      Incr Tcp_w
      Tcp_b = Tcp_w And &H000F
      If Tcp_b = 0 Then
         Print
      End If
   Loop Until Tcp_w = En_pcktlen
   Print
Return