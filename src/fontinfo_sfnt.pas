{
  SFNT-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_sfnt;

interface

uses
  fontinfo_common,
  fontinfo_utils,
  classes,
  zstream,
  strutils,
  sysutils;


procedure GetSFNTInfo(stream: TStream; var info: TFontInfo);

implementation

const
  TTF_MAGIC1 = $00010000;
  TTF_MAGIC2 = $00020000;
  TTF_MAGIC3 = $74727565; // 'true'
  TTF_MAGIC4 = $74797031; // 'typ1'

  COLLECTION_MAGIC = $74746366; // 'ttcf'
  OTF_MAGIC = $4f54544f; // 'OTTO'
  WOFF_MAGIC = $774f4646; // 'wOFF'

  EOT_MAGIC = $504c;

  // SFNT table names.
  TAG_BASE = $42415345;
  TAG_GDEF = $47444546;
  TAG_GPOS = $47504f53;
  TAG_GSUB = $47535542;
  TAG_JSTF = $4a535446;
  TAG_NAME = $6e616d65;


  FORMAT_TT = 'TT';
  FORMAT_OT_PS = 'OT PS';
  FORMAT_OT_TT = 'OT TT';


type
  TOffsetTable = packed record
    version: longword;
    num_tables,
    search_range,
    entry_selector,
    range_shift: word;
  end;

  TTableDirEntry = packed record
    tag,
    checksumm,
    offset,
    length: longword;
  end;


  TWOFFHeader = packed record
    // signature, // Already checked.
    flavor,
    length: longword;
    num_tables,
    reserved: word;
    // totalSfntSize: longword;
    // majorVersion: word;
    // minorVersion: word;
    // metaOffset,
    // metaLength,
    // metaOrigLength,
    // privOffset,
    // privLength: longword;
  end;

  TWOFFTableDirEntry = packed record
    tag,
    offset,
    comp_length,
    orig_length: longword;
    // origChecksum: longword;
  end;

  TEOTHeader = packed record
    eot_size,
    font_data_size,
    version,
    flags: longword;
    panose: array [0..9] of byte;
    charset,
    italic: byte;
    weight: longword;
    fs_type,
    magic: word;
    unicode_range1,
    unicode_range2,
    unicode_range3,
    unicode_range4,
    code_page_range1,
    code_page_range2,
    checksum_adjustment,
    reserved1,
    reserved2,
    reserved3,
    reserved4: longword;
  end;


function GetFormatSting(const sign: longword;
                        const layout_tables: boolean): string; inline;
begin
  if sign = OTF_MAGIC then
    result := FORMAT_OT_PS
  else
    if layout_tables then
      result := FORMAT_OT_TT
    else
      result := FORMAT_TT;
end;


{
 ===============
  Table reading
 ===============
}

type
  TTableReader = procedure(stream: TStream; var info: TFontInfo);

{
  orig_length indicates size of uncompressed table (from WOFF). 0 means
    that table already uncompressed.
}
procedure ReadTable(stream: TStream; var info: TFontInfo;
                    reader: TTableReader; const offset: longword;
                    const orig_length: longword = 0);
var
  start: int64;
  uncomp_data: TBytes;
  zs: TDecompressionStream;
  bs: TBytesStream;
begin
  start := stream.Position;
  stream.Seek(offset, soFromBeginning);

  if orig_length = 0 then
    reader(stream, info)
  else
    try
      zs := TDecompressionStream.Create(stream);
      try
        SetLength(uncomp_data, orig_length);
        zs.ReadBuffer(uncomp_data[0], orig_length);

        bs := TBytesStream.Create(uncomp_data);
        try
          reader(bs, info);
        finally
          bs.Free;
        end;
      finally
        zs.Free;
      end;
    except
      on EStreamError do
        begin
        end;
    end;

  stream.Seek(start, soFromBeginning);
end;



// "name" table.

const
  PLATFORM_ID_WIN = 3;
  LANGUAGE_ID_WIN_ENGLISH_US = $0409;
  ENCODING_ID_WIN_UCS2 = 1;

  VERSION_STR = 'Version ';

type
  TNamingTable = packed record
    format,
    count,
    string_offset: word;
  end;

  TNameRecord = packed record
    platform_id,
    encoding_id,
    language_id,
    name_id,
    length,
    offset: word;
  end;

procedure NameReader(stream: TStream; var info: TFontInfo);
var
  start: int64;
  naming_table: TNamingTable;
  storage_offset,
  offset: int64;
  i: longint;
  name_rec: TNameRecord;
  idx: TFieldIndex;
  name,
  version: string;
begin
  start := stream.Position;
  stream.ReadBuffer(naming_table, SizeOf(naming_table));

  {$IFDEF ENDIAN_LITTLE}
  with naming_table do
    begin
      format := SwapEndian(format);
      count := SwapEndian(count);
      string_offset := SwapEndian(string_offset);
    end;
  {$ENDIF}

  storage_offset := start + naming_table.string_offset;

  for i := 0 to naming_table.count - 1 do
    begin
      stream.ReadBuffer(name_rec, SizeOf(name_rec));

      {$IFDEF ENDIAN_LITTLE}
      with name_rec do
        begin
          platform_id := SwapEndian(platform_id);
          encoding_id := SwapEndian(encoding_id);
          language_id := SwapEndian(language_id);
          name_id := SwapEndian(name_id);
          length := SwapEndian(length);
          offset := SwapEndian(offset);
        end;
      {$ENDIF}

      // Entries in the Name Record are always sorted so that we can stop
      // parsing immediately after we finished reading the needed record.
      if (name_rec.platform_id < PLATFORM_ID_WIN) or
         (name_rec.language_id < LANGUAGE_ID_WIN_ENGLISH_US) then
        continue
      else
        if (name_rec.platform_id > PLATFORM_ID_WIN) or
           (name_rec.encoding_id > ENCODING_ID_WIN_UCS2) or
           (name_rec.language_id > LANGUAGE_ID_WIN_ENGLISH_US) then
          break;

      case name_rec.name_id of
        0:  idx := IDX_COPYRIGHT;
        1:  idx := IDX_FAMILY;
        2:  idx := IDX_STYLE;
        3:  idx := IDX_UNIQUE_ID;
        4:  idx := IDX_FULL_NAME;
        5:  idx := IDX_VERSION;
        6:  idx := IDX_PS_NAME;
        7:  idx := IDX_TRADEMARK;
        8:  idx := IDX_MANUFACTURER;
        9:  idx := IDX_DESIGNER;
        10: idx := IDX_DESCRIPTION;
        11: idx := IDX_VENDOR_URL;
        12: idx := IDX_DESIGNER_URL;
        13: idx := IDX_LICENSE;
        14: idx := IDX_LICENSE_URL;
        15: continue;  // Reserved
        16: idx := IDX_FAMILY;  // Typographic Family
        17: idx := IDX_STYLE;  // Typographic Subfamily
      else
        break;
      end;

      offset := stream.Position;
      stream.Seek(longint(storage_offset + name_rec.offset), soFromBeginning);

      SetLength(name, name_rec.length);
      stream.ReadBuffer(name[1], name_rec.length);
      info[idx] := UCS2BEToUTF8(name);

      stream.Seek(offset, soFromBeginning);
    end;

  // Strip "Version "
  version := info[IDX_VERSION];
  if (version <> '') and AnsiStartsStr(VERSION_STR, version) then
    begin
      info[IDX_VERSION] := Copy(
        version,
        Length(VERSION_STR) + 1,
        Length(version) - Length(VERSION_STR));
    end;
end;


{
  =======================
   Format-specific stuff
  =======================
}

{
  Common checker for TTF, TTC, OTF, OTC, and EOT.

  Returns boolean indicating existence of OpenType-related tables.
}
function CheckCommon(stream: TStream; var info: TFontInfo;
                     const font_offset: longword = 0): boolean;
var
  num_tables: word;
  i: longint;
  dir: TTableDirEntry;
  has_layout_tables: boolean = FALSE;
begin
  // Version is already checked.
  num_tables := stream.ReadWordBE;

  stream.Seek(
    SizeOf(TOffsetTable.search_range) +
    SizeOf(TOffsetTable.entry_selector) +
    SizeOf(TOffsetTable.range_shift),
    soFromCurrent);

  for i := 0 to num_tables - 1 do
    begin
      stream.ReadBuffer(dir, SizeOf(dir));

      {$IFDEF ENDIAN_LITTLE}
      with dir do
        begin
          tag := SwapEndian(tag);
          checksumm := SwapEndian(checksumm);
          offset := SwapEndian(offset);
          length := SwapEndian(length);
        end;
      {$ENDIF}

      case dir.tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          has_layout_tables := TRUE;
        TAG_NAME:
          ReadTable(stream, info, @NameReader, font_offset + dir.offset);
      end;
    end;

  result := has_layout_tables;
end;


{
  TTC or OTC.
}
procedure CheckCollection(stream: TStream; var info: TFontInfo);
var
  num_fonts,
  offset,
  sign: longword;
  has_layout_tables: boolean;
begin
  // Read collection header.
  stream.Seek(SizeOf(longword), soFromCurrent); // Skip version.
  num_fonts := stream.ReadDWordBE;

  if num_fonts = 0 then
    exit;

  // Read the first font.
  offset := stream.ReadDWordBE;
  stream.Seek(offset, soFromBeginning);

  sign := stream.ReadDWordBE;
  has_layout_tables := CheckCommon(stream, info);

  info[IDX_FORMAT] := GetFormatSting(sign, has_layout_tables);
  info[IDX_NUM_FONTS] := IntToStr(num_fonts);
end;


procedure CheckTTF(stream: TStream; var info: TFontInfo); inline;
var
  has_layout_tables: boolean;
begin
  has_layout_tables := CheckCommon(stream, info);

  if has_layout_tables then
    info[IDX_FORMAT] := FORMAT_OT_TT
  else
    info[IDX_FORMAT] := FORMAT_TT;
  info[IDX_NUM_FONTS] := '1';
end;


procedure CheckOTF(stream: TStream; var info: TFontInfo); inline;
begin
  CheckCommon(stream, info);
  info[IDX_FORMAT] := FORMAT_OT_PS;
  info[IDX_NUM_FONTS] := '1';
end;


procedure CheckWOFF(stream: TStream; var info: TFontInfo);
var
  header: TWOFFHeader;
  i: longint;
  dir: TWOFFTableDirEntry;
  orig_length: longword;
  has_layout_tables: boolean = FALSE;
begin
  stream.ReadBuffer(header, SizeOf(header));
  // Skip unused.
  stream.Seek(SizeOf(word) * 2 + SizeOf(longword) * 6, soFromCurrent);

  {$IFDEF ENDIAN_LITTLE}
  with header do
    begin
      flavor := SwapEndian(flavor);
      length := SwapEndian(length);
      num_tables := SwapEndian(num_tables);
      reserved := SwapEndian(reserved);
    end;
  {$ENDIF}

  if (header.length <> stream.Size) or
     (header.reserved <> 0) then
    exit;

  for i := 0 to header.num_tables - 1 do
    begin
      stream.ReadBuffer(dir, SizeOf(dir));
      // Skip origChecksum.
      stream.Seek(SizeOf(longword), soFromCurrent);

      {$IFDEF ENDIAN_LITTLE}
      with dir do
        begin
          tag := SwapEndian(tag);
          offset := SwapEndian(offset);
          comp_length := SwapEndian(comp_length);
          orig_length := SwapEndian(orig_length);
        end;
      {$ENDIF}

      if dir.comp_length > dir.orig_length then
        exit;

      if dir.comp_length < dir.orig_length then
        orig_length := dir.orig_length
      else
        orig_length := 0;

      case dir.tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          has_layout_tables := TRUE;
        TAG_NAME:
          ReadTable(stream, info, @NameReader, dir.offset, orig_length);
      end;
    end;

  info[IDX_FORMAT] := GetFormatSting(header.flavor, has_layout_tables);
  info[IDX_NUM_FONTS] := '1';
end;


const
  // EOT versions
  EOT_V1 = $00010000;
  EOT_V2 = $00020001;
  EOT_V3 = $00020002;

  // EOT flags
  TTEMBED_TTCOMPRESSED = $00000004;
  TTEMBED_XORENCRYPTDATA = $10000000;

procedure CheckEOT(stream: TStream; var info: TFontInfo);
var
  eot_size,
  font_data_size,
  version,
  flags: longword;
  magic,
  padding: word;
  font_offset,
  sign: longword;
  has_layout_tables: boolean;
  idx: TFieldIndex;
  s: string;
  s_len: word;
begin
  eot_size := stream.ReadDWordLE;
  if eot_size <> stream.Size then
    exit;

  font_data_size := stream.ReadDWordLE;
  if font_data_size >= eot_size - SizeOf(TEOTHeader) then
    exit;

  version := stream.ReadDWordLE;
  if (version <> EOT_V1) and
     (version <> EOT_V2) and
     (version <> EOT_V3) then
    exit;

  flags := stream.ReadDWordLE;

  stream.Seek(
    SizeOf(TEOTHeader.panose) +
    SizeOf(TEOTHeader.charset) +
    SizeOf(TEOTHeader.italic) +
    SizeOf(TEOTHeader.weight) +
    SizeOf(TEOTHeader.fs_type),
    soFromCurrent);

  magic := stream.ReadWordLE;
  if magic <> EOT_MAGIC then
    exit;

  if (flags and TTEMBED_TTCOMPRESSED = 0) and
     (flags and TTEMBED_XORENCRYPTDATA = 0) then
    begin
      font_offset := eot_size - font_data_size;
      stream.Seek(font_offset, soFromBeginning);

      sign := stream.ReadDWordBE;
      case sign of
        TTF_MAGIC1,
        TTF_MAGIC2,
        TTF_MAGIC3,
        TTF_MAGIC4,
        OTF_MAGIC:
          begin
            has_layout_tables := CheckCommon(stream, info, font_offset);
            info[IDX_FORMAT] := GetFormatSting(sign, has_layout_tables);
            info[IDX_NUM_FONTS] := '1';
          end;
      end;

      exit;
    end;

  stream.Seek(
    SizeOf(TEOTHeader.unicode_range1) +
    SizeOf(TEOTHeader.unicode_range2) +
    SizeOf(TEOTHeader.unicode_range3) +
    SizeOf(TEOTHeader.unicode_range4) +
    SizeOf(TEOTHeader.code_page_range1) +
    SizeOf(TEOTHeader.code_page_range2) +
    SizeOf(TEOTHeader.checksum_adjustment) +
    SizeOf(TEOTHeader.reserved1) +
    SizeOf(TEOTHeader.reserved2) +
    SizeOf(TEOTHeader.reserved3) +
    SizeOf(TEOTHeader.reserved4),
    soFromCurrent);

  for idx in [IDX_FAMILY, IDX_STYLE, IDX_VERSION, IDX_FULL_NAME] do
    begin
      padding := stream.ReadWordLE;
      if padding <> 0 then
        exit;

      s_len := stream.ReadWordLE;
      SetLength(s, s_len);
      stream.ReadBuffer(s[1], s_len);
      info[idx] := UCS2LEToUTF8(s);
    end;

  // Currently we can't uncompress EOT to determine SFNT format.
  info[IDX_FORMAT] := 'EOT';
  info[IDX_NUM_FONTS] := '1';
end;


procedure GetSFNTInfo(stream: TStream; var info: TFontInfo);
var
  sign: longword;
begin
  sign := stream.ReadDWordBE;
  case sign of
    TTF_MAGIC1,
    TTF_MAGIC2,
    TTF_MAGIC3,
    TTF_MAGIC4:
      CheckTTF(stream, info);
    OTF_MAGIC:
      CheckOTF(stream, info);
    WOFF_MAGIC:
      CheckWOFF(stream, info);
    COLLECTION_MAGIC:
      CheckCollection(stream, info);
  else
    stream.Seek(0, soFromBeginning);
    CheckEOT(stream, info);
  end;
end;


end.
