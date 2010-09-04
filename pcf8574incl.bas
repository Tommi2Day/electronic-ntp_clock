function pcf8574_read ( byval Adresse as byte)
local iicb as byte 
	'i2cInit();
	i2cStart
	iicb=adresse+1
	call i2cSlave(iicb)
	If i2cstat=1 then
		set i2cnoack
  	iicb=i2cIn()
  end if
  	
  i2cstop
  pcf8574_read=iicb
end function

sub pcf8574_write (byval Adresse as byte,datab as byte) 
'i2cInit();
	i2cStart
	call i2cSlave(adresse)
	If i2cstat=1 then
  	call i2cOut (datab) 
  end if
  i2cstop
end sub