/* LG gram 16Z90RS: fake EC device (real EC is LGEC), USBX power properties, and enable legacy RTC (STAS=1 disables AWAC) */
DefinitionBlock ("", "SSDT", 2, "LGGRAM", "ECUSBX", 0x00001000)
{
    External (_SB_.PC00.LPCB, DeviceObj)
    External (STAS, FieldUnitObj)

    Scope (\_SB.PC00.LPCB)
    {
        Device (EC)
        {
            Name (_HID, "ACID0001")
            Method (_INI, 0, NotSerialized)
            {
                If (_OSI ("Darwin"))
                {
                    STAS = One
                }
            }
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }
    }

    Scope (\_SB)
    {
        Device (USBX)
        {
            Name (_ADR, Zero)
            Method (_DSM, 4, NotSerialized)
            {
                If ((Arg2 == Zero)) { Return (Buffer (One) { 0x03 }) }
                Return (Package (0x08)
                {
                    "kUSBSleepPowerSupply", 0x13EC,
                    "kUSBSleepPortCurrentLimit", 0x0834,
                    "kUSBWakePowerSupply", 0x13EC,
                    "kUSBWakePortCurrentLimit", 0x0834
                })
            }
            Method (_STA, 0, NotSerialized)
            {
                If (_OSI ("Darwin")) { Return (0x0F) }
                Return (Zero)
            }
        }
    }
}
