/*
 * LG gram Style 16: Fn brightness keys.
 * EC _Q50/_Q51 -> N10H/N10I -> BRTN(0x86/0x87), but the DSDT BRTN only notifies
 * DD1F when (DIDX & 0x0F0F) == 0x0400, which this BIOS does not satisfy
 * (DD1F._ADR returns 0x1F). Under Darwin notify DD1F directly so BrightnessKeys
 * (which falls back to DD1F) receives the brightness up/down events.
 * Requires DSDT rename of the BRTN method definition: 4252544E09 -> 5842544E09.
 */
DefinitionBlock ("", "SSDT", 2, "HACK", "BRTN", 0x00000000)
{
    External (_SB_.PC00.GFX0.DD1F, DeviceObj)
    External (XBTN, MethodObj)    // 1 Arguments

    Method (BRTN, 1, Serialized)
    {
        If (_OSI ("Darwin"))
        {
            Notify (\_SB.PC00.GFX0.DD1F, Arg0)
        }
        Else
        {
            XBTN (Arg0)
        }
    }
}
