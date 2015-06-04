{
  BDF (Bitmap Distribution Format)
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_bdf;

interface

uses
  fontinfo_common,
  sysutils;


const
  BDF_COPYRIGHT = 'COPYRIGHT';
  BDF_FAMILY_NAME = 'FAMILY_NAME';
  BDF_FONT = 'FONT';
  BDF_FOUNDRY = 'FOUNDRY';
  BDF_FULL_NAME = 'FULL_NAME';
  BDF_WEIGHT_NAME = 'WEIGHT_NAME';


procedure GetBDFInfo(FileName: string; var info: TFontInfo);

implementation

const
  BDF_SIGN = 'STARTFONT';

  NFIELDS = 6;
  MAX_LINES = 30;


procedure GetBDFInfo(FileName: string; var info: TFontInfo);
var
  t: text;
  sign: string[Length(BDF_SIGN)];
  version: string;
  i: longint;
  s,
  key: string;
  p,
  s_len,
  nfound: longint;
  idx: TFieldIndex;
begin
  Assign(t, FileName);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

  ReadLn(t, sign, version);
  if sign = BDF_SIGN then
    begin
      info[IDX_FORMAT] := 'BDF ' + TrimLeft(version);

      i := 1;
      nfound := 0;
      while (nfound < NFIELDS) and (i <= MAX_LINES) and not EOF(t) do
        begin
          ReadLn(t, s);

          case s of
            '': continue;
            'ENDPROPERTIES': break;
          end;

          s_len := Length(s);
          p := Pos(' ', s);
          if (p < 2) or not (p < s_len - 2) then
            continue;

          inc(i);

          key := Copy(s, 1, p - 1);
          case key of
            BDF_COPYRIGHT: idx := IDX_COPYRIGHT;
            BDF_FAMILY_NAME: idx := IDX_FAMILY;
            BDF_FONT: idx := IDX_PS_NAME;
            BDF_FOUNDRY: idx := IDX_MANUFACTURER;
            BDF_FULL_NAME: idx := IDX_FULL_NAME;
            BDF_WEIGHT_NAME: idx := IDX_STYLE;
          else
            continue;
          end;

          if (s[p + 1] = '"') and (s[s_len] = '"') then
            begin
              inc(p);
              dec(s_len);
            end;

          info[idx] := Copy(s, p + 1, s_len - p);
          inc(nfound);
        end;
    end;

  if (info[IDX_FAMILY] = '') and (info[IDX_PS_NAME] <> '') then
    info[IDX_FAMILY] := info[IDX_PS_NAME];
  if info[IDX_STYLE] = '' then
    info[IDX_STYLE] := 'Medium';

  info[IDX_NFONTS] := '1';

  Close(t);
end;


end.
