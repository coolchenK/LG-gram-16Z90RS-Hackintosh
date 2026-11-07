/* Backlight device for WhateverXe on \_SB.PC00.GFX0 (Coffee Lake+ profile, _UID 0x13) */
DefinitionBlock ("", "SSDT", 2, "LGGRAM", "PNLF", 0x00000000)
{
    External (_SB_.PC00.GFX0, DeviceObj)
    If (_OSI ("Darwin"))
    {
        Scope (\_SB.PC00.GFX0)
        {
            Device (PNLF)
            {
                Name (_HID, EisaId ("APP0002"))
                Name (_CID, "backlight")
                Name (_UID, 0x13)
                Method (_STA, 0, NotSerialized) { Return (0x0B) }
            }
        }
    }
}
