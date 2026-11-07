/*
 * LG gram 16Z90RS: keep the touchpad's I2C controller (\_SB.PC00.I2C0, PCI 00:15.0) alive under macOS.
 * DSDT: _PS3 { SOD3 (IC00, One, One) } puts it in D3hot AND zeroes BAR0, while _PS0 is empty, so the
 * controller loses its MMIO base the first time macOS idles it (touchpad dead / flaky).
 * Needs ACPI patch "I2C0 _PS3 -> XPS3" (17-byte pattern containing IC00, unique in this DSDT).
 */
DefinitionBlock ("", "SSDT", 2, "LGGRAM", "I2C0PS3", 0x00000001)
{
    External (_SB_.PC00.I2C0, DeviceObj)
    External (_SB_.PC00.I2C0.XPS3, MethodObj)

    Scope (_SB.PC00.I2C0)
    {
        Method (_PS3, 0, NotSerialized)
        {
            If (!_OSI ("Darwin"))
            {
                XPS3 ()
            }
        }
    }
}
