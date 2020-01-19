# wdx_fontinfo

Font info WDX plugin for [Total][Total Commander]
and [Double][Double Commander] Commanders.

Binaries for Windows and 64-bit Linux are available on the
[Releases](https://github.com/danpla/wdx_fontinfo/releases/latest) page.


## Supported formats

* TrueType and TrueType Collections
* OpenType and OpenType Collections
* Web Open Font Format 1 & 2 (WOFF, WOFF2)
* Embedded OpenType (EOT)
* PostScript Type 0, 1, 3, 11, 42 etc., possibly with AFM, PFM, and INF
* Bitmap Distribution Format (BDF)
* X11 Portable Compiled Format (PCF), possibly GZip compressed (.pcf.gz)
* Windows’ FNT/FON
* FontForge’s Spline Font Database (SFD)


## Available fields

* Generic Family
    * "Sans"
    * "Serif"
    * "Mono"
    * "Script"
    * "Display"
    * Empty string in case the generic family is unknown.
* Family
* Style
* Full Name
* PostScript Name
* Version
* Copyright
* Unique ID
* Trademark
* Manufacturer
* Designer
* Description
* Vendor URL
* Designer URL
* License
* License URL
* Format
    * "TT" — "plain" TrueType
    * "OT PS" — PostSript flavored OpenType
    * "OT TT" — TrueType flavored OpenType
    * "EOT" — compressed Embedded OpenType (currently, the plugin can't
      decompress EOT)
    * "PS {type}" — PostScript Type {type}
    * "AFM {version}"
    * "PFM"
    * "INF"
    * "BDF {version}"
    * "PCF"
    * "FNT {version}" (both for FNT and FON)
    * "SFD {version}"
* Number of Fonts — number of fonts in TTC, OTC, or WOFF2. Always 1 for all
  other formats.


## Compilation

Ensure you have [FPC](https://www.freepascal.org/) version 2.6 or newer
and then run `compile` script.


## Links

* [OpenType Specification](https://www.microsoft.com/typography/otspec/)
* [WOFF Specification](http://www.w3.org/TR/WOFF/)
* [WOFF2 Specification](http://www.w3.org/TR/WOFF2/)
* [EOT Specification](http://www.w3.org/Submission/EOT/)
* [Apple TrueType Reference Manual](https://developer.apple.com/fonts/TrueType-Reference-Manual/)
* [PostScript Specifications](http://partners.adobe.com/public/developer/ps/index_specs.html)
* Font technical notes [[1]](http://www.adobe.com/devnet/font.html), [[2]](http://partners.adobe.com/public/developer/font/index.html)
* [PCF Specification](http://fontforge.github.io/pcf-format.html)
* FNT Specification:
    * Version 1: [Windows 1.03 SDK Programmer's Reference (Appendix C)](http://www.os2museum.com/files/docs/win10sdk/windows-1.03-sdk-prgref-1986.pdf)
    * [Version 2 and 3](https://support.microsoft.com/en-us/kb/65123)
* [FontForge’s SDF Specification](http://fontforge.github.io/en-US/documentation/developers/sfdformat/)


[Total Commander]: http://www.ghisler.com/
[Double Commander]: http://doublecmd.sourceforge.net/
