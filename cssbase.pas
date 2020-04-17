(*
  Version 0.1 Initial idea, concept proof
  Author: Pavol Stugel (pstugel@gmail.com)
  Warning: this is work in progress version, all methods can be changed in future!

  Scope:
  - very basic html(node) +  basic css layout support. KISS (https://en.wikipedia.org/wiki/KISS_principle)

  TODO (in random order):
  - transform property support
  - high dpi support
  - em length support
  - float:right, float:left support
  - image background support
  - more display:flex support
  - transition support
  - delphi support

  History:
  2020.04.17 - TCSSShape fixes, "0" length fixed
  2020.02.22 - baseline align fix, added: display:inline-flex; basic owerflow support
  2019.12.18 - fixed layout, code reorganization
  2019.12.07 - added basic display:flex support, added position (absolute,relative,static) support, fixed bugs
  2019.12.03 - added support for border and border-radius, fixed vertical-align for baseline
  2019.11.21 - fixed font size calculation, added basic class support

*)

unit cssbase;

{$ifdef fpc}
  {$mode objfpc}{$H+}
  {$modeswitch advancedrecords}
{$else}
  {$define delphi}
{$endif}

interface

uses
  Classes, SysUtils, Types,
  {$ifdef fpc}
  Controls,  Graphics,
  LCLIntf, LCLProc, LMessages, LCLType,  contnrs, LazCanvas,
  {$else}
  // delphi
  System.UITypes,
  FMX.Controls, FMX.Graphics,
  {$endif}
  Math;

const
  CSS_UNIVERSAL_SELECTOR: Char = '*';   //https://developer.mozilla.org/en-US/docs/Web/CSS/Universal_selectors
  CSS_DEBUG_MODE: Boolean = False;
  HTMLInterface = '{DD8167E4-D923-407A-AE4C-14BB93E254E3}';
  CSS_DEG_RAD = Pi / 180;

type
  TCSSBorderStyle = (cbsUndefined, cbsNone, cbsHidden, cbsDotted, cbsDashed, cbsSolid, cbsDouble, cbsGroove, cbsRidge, cbsInset, cbsOutset); // https://developer.mozilla.org/en-US/docs/Web/CSS/border-style
  TCSSFontStyle = (cfsUndefined, cfsNormal, cfsItalic, cfsOblique, cfsInherit, cfsUnset); // https://developer.mozilla.org/en-US/docs/Web/CSS/font-style
  TCSSFontWeightType = (cfwUndefined, cfwNormal, cfwBold, cfwLighter, cfwBolder, cfwInherit, cfwUnset); // https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight
  TCSSLengthType = (cltUndefined, cltPx, cltPt, cltAuto, cltEm, cltPercentage);
  TCSSTextAlign = (ctaUndefined, ctaLeft, ctaRight, ctaCenter, ctaJustify);   // https://developer.mozilla.org/en-US/docs/Web/CSS/text-align
  TCSSColorType = (cctUndefined, cctNormal);
  TCSSTextDecoration = (ctdUndefined, ctdUnderline, ctdNone);   // https://developer.mozilla.org/en-US/docs/Web/CSS/text-decoration
  TCSSDisplayType = (cdtBlock, cdtInline, cdtFlex, cdtInlineFlex, cdtNone);         // https://developer.mozilla.org/en-US/docs/Web/CSS/display
  TCSSFloatType = (cftUndefined, cftNone, cftLeft, cftRight);        // https://developer.mozilla.org/en-US/docs/Web/CSS/float
  TCSSSide = (csTop, csLeft, csBottom, csRight);        // for margin, padding etc.
  TCSSFlexWrap = (cfwNoWrap, cfwWrap, cfwWrapReverse);  // https://developer.mozilla.org/en-US/docs/Web/CSS/flex-wrap
  TCSSFlexDirection = (cfdRow, cfdColumn, cfdColumnReverse); // https://developer.mozilla.org/en-US/docs/Web/CSS/flex-direction
  TCSSPosition = (cpStatic, cpRelative, cpAbsolute, cpFixed, cpSticky); // https://developer.mozilla.org/en-US/docs/Web/CSS/position
  TCSSAlignItems = (caiStretch, caiBaseline, caiCenter, caiFlexStart, caiFlexEnd);  // https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Flexible_Box_Layout/Aligning_Items_in_a_Flex_Container
  TCSSOverflowType = (cotVisible, cotHidden, cotScroll, cotAuto);          // https://developer.mozilla.org/en-US/docs/Web/CSS/overflow

  {$ifndef fpc}
  TStringArray = array of String;
  {$endif}
  TFloatPoint = record
    x,y: Single;
  end;
  TPointArray = array of TFloatPoint;

  TCSSLength = record      // https://developer.mozilla.org/en-US/docs/Web/CSS/length
    Value: Single;
    LengthType: TCSSLengthType;
  end;

  TCSSInteger = Integer;
  TCSSNumber = Single;

  TCSSMatrix = array [0..5] of Single;

	{ TMatrixTransform }
    {
		https://www.w3.org/TR/SVG/coords.html#NestedTransformations
		Base Affine Translation Matrix
		( M0  M2  M4 )
		( M1  M3  M5 )
		( 0    0   1 )
    }
	TMatrixTransform = class
  protected
		FData: TCSSMatrix;
	public
    constructor Create; overload; virtual;
    constructor Create(M0, M1, M2, M3, M4, M5: Single); overload;
    procedure Multiply(AMatrix: TMatrixTransform);
    function Setup(M0, M1, M2, M3, M4, M5: Single): TMatrixTransform;  inline;
    function Reset: TMatrixTransform;
    function FlipHorizontal: TMatrixTransform;
    function FlipVertical: TMatrixTransform;
    function Scale(AX, AY: Single): TMatrixTransform;
    function Skew(AX, AY: Single): TMatrixTransform;
    function Rotate(Angle: Single): TMatrixTransform;
    function Translate(AX, AY: Single): TMatrixTransform;
    procedure Transform(var P: TFloatPoint);
	end;

  TCSSColor = record
    Value: TColor;
    ColorType: TCSSColorType;
  end;

  TCSSBorder = record         // https://developer.mozilla.org/en-US/docs/Web/CSS/border
    Color: TCSSColor;
    Style: TCSSBorderStyle;
    Width: TCSSLength;
  end;

  TCSSBackground = record        // https://developer.mozilla.org/en-US/docs/Web/CSS/background
    Color: TCSSColor;
  end;

  TCSSBorderRadius = record       // https://developer.mozilla.org/en-US/docs/Web/CSS/border-radius
    Width,
    Height: TCSSLength;
  end;

  TCSSFontWeight = record
    FontType: TCSSFontWeightType;
    Value: TFontStyles;
  end;

  TCSSFont = record             // https://developer.mozilla.org/en-US/docs/Web/CSS/font
    Family: String;
    Size: TCSSLength;
    Style: TCSSFontStyle;
    Weight: TCSSFontWeight;
    TextDecoration: TCSSTextDecoration;        // TODO: maybe here is not right place
    CachedText: String;       // TODO: move this part away
    CachedWidth,
    CachedHeight,
    CachedBaseLine: Integer;
  end;

   TCSSStyleSheet = class;

  { TCSSItem }

  TCSSItem = class(TPersistent)
  public
    Attributes: String;
    AlignSelf,
    AlignItems: TCSSAlignItems;
    Background: TCSSBackground;
    Color: TCSSColor;
    Cursor: TCursor;
    Changed: Boolean;
    Display: TCSSDisplayType;
    Font: TCSSFont;
    Float: TCSSFloatType;
    FlexDirection: TCSSFlexDirection;
    FlexGrow: TCSSNumber;       // default 0
    FlexWrap: TCSSFlexWrap;
    Border: array[TCSSSide] of TCSSBorder;
    Margin: array[TCSSSide] of TCSSLength;
    Padding: array[TCSSSide] of TCSSLength;
    Order: TCSSInteger; // default 0
    Overflow: TCSSOverflowType;
    Position: TCSSPosition;
    RadiusTopLeft,
    RadiusTopRight,
    RadiusBottomLeft,
    RadiusBottomRight: TCSSBorderRadius;
    TextAlign: TCSSTextAlign;
    Height,
    Width: TCSSLength;
    Top,
    Left: TCSSLength;
    Weight: Integer;        // "order" in CSS stylesheet
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure Parse(const AValue: String);
    procedure ParseFromStyleSheet(AStyleSheet: TCSSStyleSheet; const APropertyName: String);
    procedure AddProperty(AName: String; AValue: String);
    procedure AddParsedProperty(AName: String; AValue: String);
    procedure Assign(Source: TPersistent); override;
    procedure Merge(AValue: TCSSItem);
  end;

  { TCSSStyleSheet }

  TCSSStyleSheet = class(TComponent)
  private
    FList: TStringList;
    FStyle: String;
    function GetSelectorByName(AName: String): TCSSItem;
    procedure SetStyle(AValue: String);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Selector[AName: String]: TCSSItem read GetSelectorByName;
    function Append(const AValue: String): TCSSStyleSheet;
  published
    property Style: String read FStyle write SetStyle;
  end;

  { TCSSClassList }

  TCSSClassList = class                         // https://developer.mozilla.org/en-US/docs/Web/API/Element/classList
  private
    FList: TStringList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): String;
    function GetName: String;
    procedure SetName(AValue: String);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(AName: String): TCSSClassList;
    function Remove(AName: String): TCSSClassList;
    function Replace(AFrom, ATo: String): TCSSClassList;
    function Toggle(AName: String): TCSSClassList;
    property Count: Integer read GetCount;     // length
    property Name: String read GetName write SetName;
    property Item[AIndex: Integer]: String read GetItem;
  end;

  { THtmlSize }

  THtmlSize = class(TPersistent)
  public
    Position,
    ContentRect,        // MarginRect - Margin
    MarginRect: TRect;  // Margin rect (whole region)
    BaseLine: Integer;  // px from bottom of MarginRect
    Border,
    Padding,
    Margin: TRect;
    ContentWidth,                // content + border + padding
    ContentHeight: Integer;      // content + border + padding
    function TopSpace: Integer; inline;
    function LeftSpace: Integer; inline;
    function RightSpace: Integer; inline;
    function BottomSpace: Integer; inline;
    function RealContentWidth: Integer; inline;
    function RealContentRect: TRect; inline; // ContentRect - Border - Padding
  end;

  THtmlNode = class;  // forward declaration

  THtmlNodeArray = array of THtmlNode;

  { THtmlNode }

  THtmlNode = class(TPersistent)
  private
    FOnClick: TNotifyEvent;
    FHovered: Boolean;
    FParentControl: TControl;
    FFreeMe: Boolean;
    FElementName,                 // div, span ...
    FId: String;                  // id for access
    FAlignControlWasHidden: Boolean; // store if AlignControl was hidden by display style
    FAlignControl: TControl;
    FTotalCount,
    FChildCount: Integer;
    FFirstNode,
    FLastNode,
    FFirstChild,
    FNextSibling,
    FPrevSibling: THtmlNode;
    FInlineStyle,
    FHoverStyle: String;
    FText: String;
    FCompStyle: TCSSItem;          // computed active to render style
    FCompSize: THtmlSize;          // computed size

    // cache section here
    FCachedFont: TCSSFont;
    FStyleSheet: TCSSStyleSheet;
    FClassList: TCSSClassList;
    FCornerBitmap: array [0..3] of TBitmap;

    FVisible: Boolean;
    function GetStyleValue(AName: String): String;
    procedure LayoutCalcPosition(ANode: THtmlNode; TargetWidth,
      TargetHeight: Integer; out NewWidth, NewHeight: Integer);
    procedure LayoutDoFlexAlign(AParentNode: THtmlNode; AList: TList; AWidth,
      AHeight: Integer);
    function LayoutDoVerticalAlign(AList: TList; ClearList: Boolean = True): Integer;
    procedure LayoutGetNodeSize(ANode: THtmlNode; ParentWidth,
      ParentHeight: Integer; InFlex: Boolean = False);
    procedure SetHovered(AValue: Boolean);
    procedure SetHoverStyle(AValue: String);
    procedure SetInlineStyle(AValue: String);
    procedure SetStyleValue(AName: String; AValue: String);
  public
    Tag: LongInt;
    TagStr: String;
    RootNode,
    ParentNode: THtmlNode;
  protected
    procedure DrawNode(ACanvas: TCanvas; AClipRect: TRect); virtual;
    procedure CalculateSize(out AWidth, AHeight, ABaseLine: Integer);virtual;
  public
    constructor Create(AInlineStyle: String = '');virtual;
    destructor Destroy; override;

    procedure Assign(Source: TPersistent); override;
    function ApplyStyle: THtmlNode;
    function ApplyStyles: THtmlNode;
    procedure ApplyStyleForNode(ANode: THtmlNode);
    function AddNode(ANode: THtmlNode): THtmlNode;
    function AppendTo(AParentNode: THtmlNode): THtmlNode;
    function GetNext(ANode: THtmlNode; GoAboveChildren: Boolean = False): THtmlNode;
    function GetElementsByClassName(AName: String): THtmlNodeArray;
    procedure LayoutTo(ALeft, ATop, AWidth, AHeight: Integer; AAlignControls: Boolean = False);
    function NodeAtPosition(APos: TPoint): THtmlNode;
    procedure PaintTo(ACanvas: TCanvas);
    function SetAlignControl(AValue: TControl): THtmlNode;
    function SetClass(AValues: String): THtmlNode;
    function SetInline(AValue: String): THtmlNode;
    function SetId(AValue: String): THtmlNode;
    function SetHover(AValue: String): THtmlNode;
    function SetOnClick(AValue: TNotifyEvent): THtmlNode;
    function SetTagStr(AValue: String): THtmlNode;
    function Clear: THtmlNode;

    property ClassList: TCSSClassList read FClassList;
    property CompStyle: TCSSItem read FCompStyle write FCompStyle;
    property CompSize: THtmlSize read FCompSize write FCompSize;
    property Element: String read FElementName write FElementName;
    property FirstChild: THtmlNode read FFirstChild;
    property Id: String read FId write FId;
    property ParentControl: TControl read FParentControl write FParentControl;
    property Style[AName: String]: String read GetStyleValue write SetStyleValue;
    property Text: String read FText write FText;
    property Hovered: Boolean read FHovered write SetHovered;
    property ChildCount: Integer read FChildCount;

  published
    property AlignControl: TControl read FAlignControl write FAlignControl;
    property InlineStyle: String read FInlineStyle write SetInlineStyle;
    property HoverStyle: String read FHoverStyle write SetHoverStyle;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property StyleSheet: TCSSStyleSheet read FStyleSheet write FStyleSheet;
  end;

  THtmlNodeList = class
  end;

  ICSSControl = interface
    [HTMLInterface]
    function GetBodyNode: THtmlNode;
    procedure Changed;
  end;

  TColorObject = class
    Value: TColor;
  end;

  procedure ParseCSS(ACSS: String; ATarget: TStringList);
  function StrBefore(const AValue: String; const ASubstr: String): String;
  function StrAfter(const AValue: String; const ASubstr: String): String;
  function StrBetween(const AValue: String; const AStart, AEnd: String): String;
  function HTMLDiv(AInlineStyle: String; AId: String = ''): THtmlNode;
  function HTMLSpan(AInlineStyle: String; AText: String = ''; AId: String = ''): THtmlNode;

implementation
// TODO: add all css colors

const
  CSS_COLOR_KEYWORDS : array[0..15] of record         // "css level 1" https://developer.mozilla.org/en-US/docs/Web/CSS/color_value
    k: String;                                        // key
    v: String;                                        // value stored in CSS format is slow but better for future
  end = (
    (k:'black'; v:'#000000'),
    (k:'silver'; v:'#c0c0c0'),
    (k:'gray'; v: '#808080'),
    (k:'white'; v:'#ffffff'),
    (k:'maroon'; v:'#800000'),
    (k:'red'; v:'#ff0000'),
    (k:'purple'; v:'#800080'),
    (k:'fuchsia'; v:'#ff00ff'),
    (k:'green'; v:'#008000'),
    (k:'lime'; v:'#00ff00'),
    (k:'olive'; v:'#808000'),
    (k:'yellow'; v:'#ffff00'),
    (k:'navy'; v:'#000080'),
    (k:'blue'; v:'#0000ff'),
    (k:'teal'; v:'#008080'),
    (k:'aqua'; v:'#00ffff')
  );
var
  CSSColorList: TStringList;

function FPoint(x,y: Single): TFloatPoint; inline;
begin
  Result.x := x;
  Result.y := y;
end;

function StrBefore(const AValue: String; const ASubstr: String): String;
var
  I: Integer;
begin
  I := Pos(ASubstr, AValue);
  if I <> -1 then  Result := Copy(AValue, 1, I -1)
    else Result := '';
end;

function StrAfter(const AValue: String; const ASubstr: String): String;
var
  I: Integer;
begin
  I := Pos(ASubstr, AValue);
  if I <> -1 then  Result := Copy(AValue, I + Length(ASubstr), Length(AValue))
    else Result := '';
end;

function StrBetween(const AValue: String; const AStart, AEnd: String): String;
begin
  Result := StrBefore(StrAfter(AValue, AStart), AEnd);
end;

function StrPart(var AValue: String; const APipe: String='|'): String;
var
	i: Integer;
begin
	i := Pos(APipe, AValue);
	if i <> 0 then begin
		Result := Copy(AValue, 1, i - 1);
		AValue := Copy(AValue, i + Length(APipe), Length(AValue));
	end
	else begin
		Result := AValue;
		AValue := '';
	end;
end;

function HTMLDiv(AInlineStyle: String; AId: String): THtmlNode;
begin
  Result := THtmlNode.Create;
  Result.InlineStyle := AInlineStyle;
  Result.Id := AId;
end;

function HTMLSpan(AInlineStyle: String; AText: String = ''; AId: String = ''): THtmlNode;
begin
  Result := THtmlNode.Create;
  Result.FElementName := 'span';
  Result.InlineStyle := AInlineStyle;
  Result.Id := AId;
  Result.Text := AText;
end;

(*
  Remove all comments and empty(double..) spaces and line breaks
*)
procedure CleanCSS(var AValue: String);
var
  S: String;
  I, T: Integer;
  CurCh, PrevCh: Char;
  InQuotes,
  InComment: Boolean;
begin
  if Length(AValue) = 0 then Exit;
  S := AValue;
  T := 1;
  PrevCh := #0;
  InComment := False;
  InQuotes := False;
  for I := 1 to Length(S) do begin
    CurCh  := S[I];
    if (not InComment) and not(CurCh in [#9, #10, #11, #13])  then begin
      S[T] := S[I];
      Inc(T);
    end;
    if CurCh in ['"', ''''] then InQuotes := not InQuotes;
    if CurCh in [#10, #11, #13] then InQuotes := False;
    if not InQuotes then begin
      if (CurCh = ' ') and (PrevCh = ' ') then Dec(T); // skip empty spaces
      if (CurCh ='*') and (PrevCh ='/') then begin
        InComment := True;
        Dec(T);
      end;
      if (CurCh ='/') and (PrevCh ='*') then begin
        InComment := False;
        Dec(T,1);
      end;
    end;
    PrevCh := CurCh;
  end;
  AValue := Copy(S, 1, T-1);
end;

function DivideToStringList(const AValue:String; Delimiter: Char; Sort: Boolean = False): TStringList;
var
  Len,
  I, J: Integer;
begin
  Result := TStringList.Create;
  Result.Sorted := Sort;
  if AValue = '' then exit;
  I := 1;
  J := 1;
  Len := Length(AValue);
  while I <= Len do begin
    if (AValue[I] = Delimiter) or (I = Len) then  begin
      if (I = Len) and (AValue[I] <> Delimiter) then Inc(I);
      if (I - J) > 0 then Result.Add(Copy(AValue, J, I - J));
      J := I + 1;
    end;
    Inc(I);
  end;
end;

function SplitParameters(const AValue: String; Delimiter: Char=' '): TStringArray;
const
  ExpandSize = 6;
var
  Count,
  Len,
  I, J: Integer;
  InRound: Integer;
begin
  if AValue = '' then exit;
  SetLength(Result, 10);
  Count :=0;
  I := 1;
  J := 1;
  InRound := 0;
  Len := Length(AValue);
  while I <= Len do begin
    if AValue[I] = '(' then
      Inc(InRound) else
    if AValue[I] = ')' then
      Dec(InRound);
    if ((AValue[I] = Delimiter) and (InRound<1)) or (I = Len) then begin
      if I = Len then Inc(I);
      if (I - J) > 0 then begin
        if Length(Result) <= Count then
          SetLength(Result, Length(Result) + ExpandSize);
        Result[Count] := Copy(AValue, J, I - J);
        Inc(Count);
        if (I > Len) and (Result[Count-1] = Delimiter) then Dec(Count);
      end;
      J := I + 1;
    end;
    Inc(I);
  end;
  SetLength(Result, Count);
end;

{$ifdef delphi}
function RGBToColor(R, G, B: Byte): TColor;
begin
  Result := (B shl 16) or (G shl 8) or R;
end;
{$endif}

function ForceRange(x, xmin, xmax: Integer): Integer;
begin
  if x < xmin then
    Result := xmin
  else if x > xmax then
    Result := xmax
  else
    Result := x;
end;

function CSSToFontWeight(AValue: String): TCSSFontWeight;
begin
  // TODO: add another values
  if AValue = 'bold' then begin
    Result.FontType := cfwBold;
    Result.Value := [{$ifdef delphi}TFontStyle.{$endif}fsBold];
  end
  else begin
    Result.FontType := cfwUndefined;
    Result.Value := [];
  end;
end;

function CSSToTextAlign(AValue: String): TCSSTextAlign;
begin
  if AValue = '' then Exit(ctaUndefined);
  case AValue[1] of
    'l': Result := ctaLeft;     // left
    'r': Result := ctaRight;    // righ
    'c': Result := ctaCenter;   // center
    'j': Result := ctaJustify;  // justify
  end;
end;

function CSSToAlignItems(AValue: String): TCSSAlignItems;
begin
  if AValue = '' then Exit(caiStretch);
  case AValue[1] of
    'f': if AValue = 'flex-start' then Result := caiFlexStart else Result := caiFlexEnd;
    'c': Result := caiCenter; // center
    's': Result := caiStretch; // stretch
    'b': Result := caiBaseline; // baseline
  end;
end;

function CSSToOverflowType(AValue: String): TCSSOverflowType;
begin
  if AValue = '' then Exit(cotVisible);
  case AValue[1] of
    'v': Result := cotVisible; // visible
    'h': Result := cotHidden; // hidden
    'a': Result := cotAuto; // auto
    's': Result := cotScroll; // scroll
  end;
end;

function CSSToBorderStyle(AValue: String): TCSSBorderStyle;
begin
  if AValue = 'solid' then Result := cbsSolid else
  if AValue = 'dotted' then Result := cbsDotted else
    Result := cbsUndefined;
end;

function CSSFontStyleFromName(S: String): TCSSFontStyle;
begin
  Result := cfsNormal;
  if length(s)<2 then exit;
  case S[2] of
    'b': if S = 'oblique' then Result := cfsOblique;
    'n': if S = 'inherit' then Result := cfsInherit;
    't': if S = 'italic' then Result := cfsItalic;
  end;
end;

function CSSToLength(AValue: String): TCSSLength;
var
  fs: TFormatSettings;
begin
  if AValue.Contains('px') then begin
    Result.Value := StrToIntDef(StrBefore(AValue, 'px'), 0);
    Result.LengthType := cltPx;
  end else
  if AValue.Equals('0') then begin
    Result.Value := 0;
    Result.LengthType := cltPx;
  end else
  if AValue.Contains('%') then begin
    fs.DecimalSeparator := '.';
    Result.Value := StrToFloat(StrBefore(AValue, '%'), fs);
    Result.LengthType := cltPercentage;
    if Result.Value > 100 then Result.Value := 100;
  end else
  if AValue.Equals('auto') then begin
    Result.LengthType := cltAuto;
  end else
    Result.LengthType := cltUndefined;
end;

function CSSToPosition(AValue: String): TCSSPosition;
begin
  Result := cpStatic;
  if AValue = 'relative' then Result := cpRelative else
  if AValue = 'absolute' then Result := cpAbsolute else
  if AValue = 'sticky' then Result := cpSticky;
end;

(*
  Only two basic types are supported
*)
function CSSToDisplay(AValue: String): TCSSDisplayType;
begin
  if AValue.Equals('inline') or AValue.Equals('inline-block') then Result := cdtInline else
  if AValue.Equals('block') then Result := cdtBlock else
  if AValue.Equals('flex') then Result := cdtFlex else
  if AValue.Equals('inline-flex') then Result := cdtInlineFlex else
  if AValue.Equals('none') then Result := cdtNone else
    Result := cdtBlock;
end;

function CSSToFloat(AValue: String): TCSSFloatType;
begin
  if AValue.Equals('left') then Result := cftLeft else
  if AValue.Equals('right') then Result := cftRight else
    Result := cftNone;
end;

function CSSToCursor(AValue: String): TCursor;
begin
  //TODO: add some basic cursors here
  if AValue = 'pointer' then Result := crHandPoint else
  if AValue = 'wait' then Result := crHourGlass else
  if AValue = 'text' then Result := crIBeam else
  if AValue = 'move' then Result := crSizeAll else
  Result := crDefault;
end;

(*
    Convert HTML colors to LCL colors
*)
function CSSToColor(AValue: String): TCSSColor;
var
  R,G,B: Byte;
  X: Integer;
  s: String;
begin
  Result.ColorType := cctUndefined;
  AValue := Trim(AValue);
  if AValue.IsEmpty then
    Exit;
  if AValue[1] = '#' then begin
    if Length(AValue) = 7 then begin
      R := StrToInt('$'+Copy(AValue, 2, 2));
      G := StrToInt('$'+Copy(AValue, 4, 2));
      B := StrToInt('$'+Copy(AValue, 6, 2));
      Result.Value := RGBToColor(R, G, B);
      Result.ColorType := cctNormal;
    end else
    if Length(AValue) = 4 then begin
      R:= StrToInt('$' + AValue[2] + AValue[2]);
      G:= StrToInt('$' + AValue[3] + AValue[4]);
      B:= StrToInt('$' + AValue[4] + AValue[5]);
      Result.Value := RGBToColor(R, G, B);
      Result.ColorType := cctNormal;
    end;
  end else
  if AValue.StartsWith('rgb') then begin
    s := StrBetween(AValue, '(', ')');
    R := StrToInt(Trim(StrPart(s, ',')));
    G := StrToInt(Trim(StrPart(s, ',')));
    B := StrToInt(Trim(StrPart(s, ',')));
    Result.Value := RGBToColor(R, G, B);
    Result.ColorType := cctNormal;
  end
  else begin
    if CSSColorList.Find(AValue, X) then begin
      Result.Value := TColorObject(CSSColorList.Objects[X]).Value;
      Result.ColorType := cctNormal;
    end;
  end;
end;

(*
  generate css color table based on CSS_COLOR_KEYWORDS
*)

procedure InitCSSColors;
var
  I: Integer;
  Item: TColorObject;
begin
  CSSColorList := TStringList.Create;
  CSSColorList.Sorted := True;
  CSSColorList.OwnsObjects := True;
  for I := 0 to High(CSS_COLOR_KEYWORDS) do begin
    Item := TColorObject.Create;
    Item.Value := CSSToColor( CSS_COLOR_KEYWORDS[I].V).Value;
    CSSColorList.AddObject(CSS_COLOR_KEYWORDS[I].K, Item);
  end;
end;

procedure TryCSSToLength(const AParts: TStringArray; var ATarget: TCSSLength);
var
  I: Integer;
begin
  for I := 0 to High(AParts) do begin
    if AParts[I].IsEmpty then Continue;
    if AParts[I].EndsWith('px') then begin
      ATarget.Value := StrToIntDef(StrBefore(AParts[I], 'px'), 0);
      ATarget.LengthType := cltPx;
      AParts[I] := '';
    end else
    if AParts[I].EndsWith('em') then begin
      ATarget.LengthType := cltEm;
      ATarget.Value := StrToIntDef(StrBefore(AParts[I], 'em'), 0);
      AParts[I] := '';
    end;
  end;
end;

procedure TryCSSToBorderStyle(const AParts: TStringArray; var ATarget: TCSSBorderStyle);
var
  I: Integer;
  S: String;
begin
  for I := 0 to High(AParts) do begin
    S := AParts[I];
    if S.IsEmpty then Continue;
    if S.Equals('solid') then begin
        ATarget := cbsSolid;
        AParts[I] := '';
    end else
    if S.Equals('dotted') then begin
      ATarget := cbsNone;
      AParts[I] := '';
    end else
    if S.Equals('none') then begin
      ATarget := cbsNone;
      AParts[I] := '';
    end else
    if S.Equals('dashed') then begin
      ATarget := cbsDashed;
      AParts[I] := '';
    end;
  end;
end;

procedure TryCSSToColor(const AParts: TStringArray; var ATarget: TCSSColor);
var
  I: Integer;
begin
  for I := 0 to High(AParts) do begin
    if AParts[I].IsEmpty then Continue;
    ATarget := CSSToColor(AParts[I]);
    if ATarget.ColorType <> cctUndefined then AParts[I] := '';
  end;
end;

function CSSToBorder(AValue: String): TCSSBorder;
var
  Parts: TStringArray;
begin
  Parts := SplitParameters(AValue);
  case High(Parts) of
    0: // STYLE
      begin
        TryCSSToBorderStyle(Parts, Result.Style);
      end;
    1: // STYLE | COLOR in any order
      begin
        TryCSSToBorderStyle(Parts, Result.Style);
        TryCSSToColor(Parts, Result.Color);
      end;
    2: // STYLE | COLOR | WIDTH in any order
      begin
        TryCSSToBorderStyle(Parts, Result.Style);
        TryCSSToLength(Parts, Result.Width);
        TryCSSToColor(Parts, Result.Color);
      end;
  end;
end;

(*
    AValue can be:
      - one value
      - two values with space
*)
function CSSToBorderRadius(AValue: String): TCSSBorderRadius;
var
  I: Integer;
begin
  I := Pos(' ', AValue) ;
  if I > 0 then begin
    Result.Width := CSSToLength( Copy(AValue, 1, I));
    Result.Height := CSSToLength( Copy(AValue, I+1, MaxInt));
  end else begin
    Result.Width := CSSToLength(AValue);
    Result.Height := Result.Width;
  end;
end;

function CSSToFont(AValue: String): TCSSFont;
var
  Parts: TStringArray;
begin
  Parts := SplitParameters(AValue);
  Result.Family := '';
  Result.TextDecoration := ctdUndefined;
  Result.Weight.FontType := cfwUndefined;
  Result.Weight.Value := [];
  Result.Size.LengthType := cltUndefined;
  TryCSSToLength(Parts, Result.Size);
end;

function CSSToTextDecoration(AValue: String): TCSSTextDecoration;
begin
  if AValue = 'underline' then Result := ctdUnderline else
  if AValue = 'none' then Result := ctdNone else
    Result := ctdUndefined;
end;

(*
    Parse whole CSS file and write it to CSSItems
*)

procedure ParseCSS(ACSS: String; ATarget: TStringList);
var
  Prop: TCSSItem;
  Sl: TStringList;
  AttCounter,
  OI,
  I, T, X: Integer;
  CurCh: Char;
  S,
  Attributes,
  Selectors: String;
  InQuotes: Boolean;
begin
  CleanCSS(ACSS);
  if Length(ACSS) = 0 then Exit;
  InQuotes := False;
  T := 1;
  AttCounter := 0;
  Sl := TStringList.Create;
  Sl.Delimiter := ',';
  for I := 1 to Length(ACSS) do begin
    CurCh := ACSS[I];
    if CurCh in ['"', ''''] then InQuotes := not InQuotes;
    if CurCh in [#10, #11, #13] then InQuotes := False;
    if not InQuotes then begin
      if CurCh = '{' then begin
        if AttCounter = 0 then begin
          Selectors := Copy(ACSS, T, I-T);
          T := I;
        end;
        Inc(AttCounter);
      end;
      if CurCh = '}' then begin
        if AttCounter = 1 then begin
          Attributes := Copy(ACSS, T+1, I-T -1);
          Sl.DelimitedText := Selectors;
          for X := 0 to Sl.Count -1 do begin
            S := Trim(Sl.Strings[X]);
            if ATarget.Find(S, OI) then ATarget.Delete(OI);
            Prop := TCSSItem.Create;
            Prop.Attributes := Attributes;
            Prop.Weight := ATarget.Count;
            ATarget.AddObject(S, Prop);
          end;
          T := I+1;
          AttCounter := 0;
        end else Dec(AttCounter);
      end;
    end;
  end;
  Sl.Free;
end;

function CalcCSSLength(AValue: TCSSLength; ParentLength: Integer): Integer;
begin
  case AValue.LengthType of
    cltPercentage: Result := Round((ParentLength/100) * AValue.Value);
    cltPx: Result := Round(AValue.Value);
    cltEm: Result := Round(AValue.Value); // TODO
    cltAuto: Result := MaxInt;
    else
      Result := 0;
  end;
end;

procedure SinCos(const Theta, RadiusX, RadiusY: Single; out Sin, Cos: Single);
var
	S, C: Extended;
begin
	Math.SinCos(Theta, S, C);
	Sin := S * RadiusY;
	Cos := C * RadiusX;
end;

procedure _BuildArc(var APoly: TPointArray; const P: TPoint ; a1, a2, rX, rY: Single; Steps: Integer);
var
	StartI,
	I, N: Integer;
	a, da, dx, dy: Single;
begin
	StartI := Length(APoly);
	SetLength( APoly, Length(APoly) + Steps);

	N := Steps - 1;
	da := (a2 - a1) / N;
	a := a1;
	for I := 0 to N do begin
		SinCos(a, rX, rY, dy, dx);
		APoly[StartI + I].X := (P.X + dx);
		APoly[StartI + I].Y := (P.Y + dy);
		a := a + da;
	end;
end;

procedure BuildArc(var APoly: TPointArray; const P: TPoint; StartAngle, EndAngle, Width, Height: Single);
const
	MINSTEPS = 6;
var
	Steps: Integer;
begin
	StartAngle := StartAngle * CSS_DEG_RAD;
	EndAngle := EndAngle * CSS_DEG_RAD;
	Steps := Max(MINSTEPS, 1 * System.Round(Sqrt(Abs( Max(Width, Height))) * Abs(EndAngle - StartAngle)));
	_BuildArc(APoly, P, StartAngle, EndAngle, Width, Height, Steps);
end;

{ THtmlSize }

function THtmlSize.TopSpace: Integer;
begin
  Result := Margin.Top + Padding.Top + Border.Top;
end;

function THtmlSize.LeftSpace: Integer;
begin
  Result := Margin.Left + Padding.Left + Border.Left;
end;

function THtmlSize.RightSpace: Integer;
begin
  Result := Margin.Right + Padding.Right + Border.Right;
end;

function THtmlSize.BottomSpace: Integer;
begin
  Result := Margin.Bottom + Padding.Bottom + Border.Bottom;
end;

function THtmlSize.RealContentWidth: Integer;
begin
  Result := ContentWidth - Padding.Left - Padding.Right - Border.Left - Border.Right;
end;

function THtmlSize.RealContentRect: TRect;
begin
  Result := Rect( ContentRect.Left + Border.Left + Padding.Left,
  ContentRect.Top + Border.Top + Padding.Top,
  ContentRect.Right - Border.Right - Padding.Right,
  ContentRect.Bottom - Border.Bottom - Padding.Bottom);
end;

{ TMatrixTransform }

constructor TMatrixTransform.Create;
begin
  Reset;
end;

constructor TMatrixTransform.Create(M0, M1, M2, M3, M4, M5: Single);
begin
  Setup(M0, M1, M2, M3, M4, M5);
end;

function TMatrixTransform.Setup(M0, M1, M2, M3, M4, M5: Single
  ): TMatrixTransform;  {$ifdef fpc}inline;{$endif}
begin
	FData[0] := M0;
	FData[1] := M1;
	FData[2] := M2;
	FData[3] := M3;
	FData[4] := M4;
	FData[5] := M5;
  Result := Self;
end;

procedure TMatrixTransform.Multiply(AMatrix: TMatrixTransform);
var
	T0, T2, T4: Single; // temps
begin
	T0 := FData[0] * AMatrix.FData[0] + FData[1] * AMatrix.FData[2];
	T2 := FData[2] * AMatrix.FData[0] + FData[3] * AMatrix.FData[2];
	T4 := FData[4] * AMatrix.FData[0] + FData[5] * AMatrix.FData[2] + AMatrix.FData[4];
	FData[1] := FData[0] * AMatrix.FData[1] + FData[1] * AMatrix.FData[3];
	FData[3] := FData[2] * AMatrix.FData[1] + FData[3] * AMatrix.FData[3];
	FData[5] := FData[4] * AMatrix.FData[1] + FData[5] * AMatrix.FData[3] + AMatrix.FData[5];
	FData[0] := T0;
	FData[2] := T2;
	FData[4] := T4;
end;

function TMatrixTransform.Reset: TMatrixTransform;
begin
  Setup(1, 0, 0, 1, 0, 0);
  Result := Self;
end;

function TMatrixTransform.FlipHorizontal: TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(-1, 0, 0, 1, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.FlipVertical: TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(1, 0, 0, -1, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.Scale(AX, AY: Single): TMatrixTransform;
begin
	FData[0] := FData[0] * AX;
	FData[2] := FData[2] * AX;
	FData[4] := FData[4] * AX;
	FData[1] := FData[1] * AY;
	FData[3] := FData[3] * AY;
	FData[5] := FData[5] * AY;
	Result := Self;
end;

function TMatrixTransform.Skew(AX, AY: Single): TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(1, Tan(AY * CSS_DEG_RAD), Tan(AX * CSS_DEG_RAD), 1, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.Rotate(Angle: Single): TMatrixTransform;  // https://www.w3.org/TR/SVG/coords.html#RotationDefined
var
	Ca, Sa: Single;
	Temp: TMatrixTransform;
begin
	Math.SinCos(Angle * CSS_DEG_RAD, Sa, Ca);
	Temp := TMatrixTransform.Create(Ca, Sa, - Sa, Ca, 0, 0);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

function TMatrixTransform.Translate(AX, AY: Single): TMatrixTransform;
var
	Temp: TMatrixTransform;
begin
	Temp := TMatrixTransform.Create(1, 0, 0, 1, AX, AY);
	try
		Self.Multiply(Temp);
	finally
		Temp.Free;
	end;
	Result := Self;
end;

procedure TMatrixTransform.Transform(var P: TFloatPoint);
var
	Tx: Single;
begin
	Tx := P.X;
	P.X := Tx * FData[0] + P.Y * FData[2] + FData[4];
	P.Y := Tx * FData[1] + P.Y * FData[3] + FData[5];
end;

{ TCSSClassList }

function TCSSClassList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TCSSClassList.GetItem(AIndex: Integer): String;
begin
  Result := FList.Strings[AIndex];
end;

function TCSSClassList.GetName: String;
begin
  FList.Delimiter := ' ';
  Result := FList.CommaText;
end;

procedure TCSSClassList.SetName(AValue: String);
begin
  {$ifdef fpc}FreeThenNil(FList);{$else}FList.Free;{$endif}
  FList := DivideToStringList(AValue, ' ', True);
  FList.Delimiter := ' ';
end;

constructor TCSSClassList.Create;
begin
  FList :=  TStringList.Create;
  FList.Duplicates := dupIgnore;
  FList.OwnsObjects := True;
  FList.Sorted := True;
end;

destructor TCSSClassList.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TCSSClassList.Add(AName: String): TCSSClassList;
begin
  Result := Self;
  FList.Add(AName);
end;

function TCSSClassList.Remove(AName: String): TCSSClassList;
var
  I: Integer;
begin
  Result := Self;
  if FList.Find(AName, I) then FList.Delete(I);
end;

function TCSSClassList.Replace(AFrom, ATo: String): TCSSClassList;
var
  I: Integer;
begin
  Result := Self;
  if FList.Find(AFrom, I) then begin
    FList.Delete(I);
    FList.Add(ATo);
  end;
end;

function TCSSClassList.Toggle(AName: String): TCSSClassList;
var
  I: Integer;
begin
  Result := Self;
  if FList.Find(AName, I) then FList.Delete(I) else FList.Add(AName);
end;

{ TCSSStyleSheet }

procedure TCSSStyleSheet.SetStyle(AValue: String);
begin
  FStyle := AValue;
  FList.Clear;
  ParseCSS(FStyle, FList);
end;

function TCSSStyleSheet.GetSelectorByName(AName: String): TCSSItem;
var
  I: Integer;
begin
  if FList.Find(AName, I) then Result := TCSSItem(FList.Objects[I]) else Result := Nil;
end;

constructor TCSSStyleSheet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FList := TStringList.Create;
  FList.OwnsObjects := True;
  FList.Sorted := True;
  FList.Duplicates := dupError;
end;

destructor TCSSStyleSheet.Destroy;
begin
  FList.Free;
  inherited Destroy;
end;

function TCSSStyleSheet.Append(const AValue: String): TCSSStyleSheet;
begin
  Result := Self;
  if AValue <> '' then
    ParseCSS(AValue, FList);
end;

{ TCSSItem }

constructor TCSSItem.Create;
begin
  Background.Color.ColorType := cctUndefined;
  Changed := False;
  Reset;
end;

destructor TCSSItem.Destroy;
begin
  inherited Destroy;
end;

procedure TCSSItem.Reset;
var
  L: TCSSSide;
begin
  Background.Color.ColorType := cctUndefined;
  Color.ColorType := cctUndefined;
  Cursor := crDefault;
  Display := cdtBlock;
  Width.LengthType := cltUndefined;
  Height.LengthType := cltUndefined;
  Font.TextDecoration := ctdUndefined;
  Font.Weight.FontType := cfwUndefined;
  Font.Weight.Value := [];
  for L := Low(TCSSSide) to High(TCSSSide) do  Margin[L].LengthType := cltUndefined;
  for L := Low(TCSSSide) to High(TCSSSide) do  Padding[L].LengthType := cltUndefined;
  for L := Low(TCSSSide) to High(TCSSSide) do  Border[L].Width.LengthType := cltUndefined;
end;

(*
  Parse css property separated with ";". Eg.: background-color:red;margin-top: 10px;
*)
procedure TCSSItem.Parse(const AValue: String);
var
  PropertyList: TStringlist;
  S, PName: String;
  I: Integer;
begin
  PropertyList := DivideToStringList(AValue, ';');
  for I := 0 to PropertyList.Count-1 do begin
    S := PropertyList.Strings[I];
    PName := Copy(S, 1, Pos(':', S) - 1);
    S := Copy(S, Length(PName) + 2, Length(S));
    if (s = '') or (PName = '') then Continue;
    AddProperty(AnsiLowerCase(PName), S);
  end;
  Changed := True;
  PropertyList.Free;
end;

procedure TCSSItem.ParseFromStyleSheet(AStyleSheet: TCSSStyleSheet; const APropertyName: String);
var
  cs: TCSSItem;
begin
  cs := AStyleSheet.Selector[APropertyName];
  if Assigned(cs) then Self.Parse(cs.Attributes);
end;

procedure TCSSItem.AddProperty(AName: String; AValue: String);
var
  Parts: TStringArray;
begin
  AName := Trim(AName);
  AValue := Trim(AValue);
  if (AName = 'margin') or (AName = 'padding') then begin // shorthand values https://developer.mozilla.org/en-US/docs/Web/CSS/margin
    Parts := SplitParameters(AValue);
    case High(Parts) of
      0:begin
          AddParsedProperty(AName + '-top', AValue);
          AddParsedProperty(AName + '-right', AValue);
          AddParsedProperty(AName + '-bottom', AValue);
          AddParsedProperty(AName + '-left', AValue);
        end;
      1:begin
          AddParsedProperty(AName + '-top', Parts[0]);
          AddParsedProperty(AName + '-bottom', Parts[0]);
          AddParsedProperty(AName + '-left', Parts[1]);
          AddParsedProperty(AName + '-right', Parts[1]);
        end;
      2:begin
          AddParsedProperty(AName + '-top', Parts[0]);
          AddParsedProperty(AName + '-left', Parts[1]);
          AddParsedProperty(AName + '-right', Parts[1]);
          AddParsedProperty(AName + '-bottom', Parts[2]);
        end;
      3:begin
          AddParsedProperty(AName + '-top', Parts[0]);
          AddParsedProperty(AName + '-right', Parts[1]);
          AddParsedProperty(AName + '-bottom', Parts[2]);
          AddParsedProperty(AName + '-left', Parts[3]);;;
        end;
    end; // case
  end else
  if (AName = 'border') then begin
    AddParsedProperty(AName+ '-top', AValue);
    AddParsedProperty(AName+ '-left', AValue);
    AddParsedProperty(AName+ '-bottom', AValue);
    AddParsedProperty(AName+ '-right', AValue);
  end else
  if (AName = 'border-radius') then begin
    Parts := SplitParameters(AValue);
    case High(Parts) of
      0:begin
          AddParsedProperty('border-top-left-radius', AValue);
          AddParsedProperty('border-top-right-radius', AValue);
          AddParsedProperty('border-bottom-right-radius', AValue);
          AddParsedProperty('border-bottom-left-radius', AValue);
        end;
      1:begin
          AddParsedProperty('border-top-left-radius', Parts[0]);
          AddParsedProperty('border-top-right-radius', Parts[1]);
          AddParsedProperty('border-bottom-right-radius', Parts[0]);
          AddParsedProperty('border-bottom-left-radius', Parts[1]);
        end;
      3:begin
          AddParsedProperty('border-top-left-radius', Parts[0]);
          AddParsedProperty('border-top-right-radius', Parts[1]);
          AddParsedProperty('border-bottom-right-radius', Parts[2]);
          AddParsedProperty('border-bottom-left-radius', Parts[3]);
        end;
    end;
  end
  else AddParsedProperty(AName, AValue);
end;

procedure TCSSItem.AddParsedProperty(AName: String; AValue: String);
begin
  if AValue = '' then Exit;
  case AName[1] of
    'a':
      if AName = 'align-items' then
        AlignItems := CSSToAlignItems(AValue)
      else
      if AName = 'align-self' then
        AlignSelf := CSSToAlignItems(AValue);
    'b':
      if AName = 'border-top' then
        Border[csTop] := CSSToBorder(AValue)
      else
      if AName = 'border-left' then
        Border[csLeft] := CSSToBorder(AValue)
      else
      if AName = 'border-bottom' then
        Border[csBottom] := CSSToBorder(AValue)
      else
      if AName = 'border-right' then
        Border[csRight] := CSSToBorder(AValue)
      else
      if AName = 'background-color' then
        Background.Color := CSSToColor(AValue)
      else
      if AName = 'border-top-left-radius' then
        RadiusTopLeft := CSSToBorderRadius(AValue)
      else
      if AName = 'border-top-right-radius' then
        RadiusTopRight := CSSToBorderRadius(AValue)
      else
      if AName = 'border-bottom-left-radius' then
        RadiusBottomLeft := CSSToBorderRadius(AValue)
      else
      if AName = 'border-bottom-right-radius' then
        RadiusBottomRight := CSSToBorderRadius(AValue);
    'c':
      if AName = 'color' then
        Color := CSSToColor(AValue)
      else
      if AName = 'cursor' then
        Cursor := CSSToCursor(AValue);
    'd':
      if AName = 'display' then
        Display := CSSToDisplay(AValue);
    'f':
      if AName = 'flex-grow' then
        FlexGrow := StrToFloat(AValue) // TODO: better conversion
      else
      if AName = 'float' then
        Float := CSSToFloat(AValue)
      else
      if AName = 'font' then
        Font := CSSToFont(AValue)
      else
      if AName = 'font-weight' then
        Font.Weight := CSSToFontWeight(AValue);
    'l':
      if AName = 'left' then
        Left := CSSToLength(AValue);
    'm':
      if AName = 'margin-left' then
        Margin[csLeft] := CSSToLength(AValue)
      else
      if AName = 'margin-top' then
        Margin[csTop] := CSSToLength(AValue)
      else
      if AName = 'margin-bottom' then
        Margin[csBottom] := CSSToLength(AValue)
      else
      if AName = 'margin-right' then
        Margin[csRight] := CSSToLength(AValue);
    'o':
      if AName = 'overflow' then
        Overflow := CSSToOverflowType(AValue);
    'p':
      if AName = 'padding-left' then
        Padding[csLeft] := CSSToLength(AValue)
      else
      if AName = 'padding-top' then
        Padding[csTop] := CSSToLength(AValue)
      else
      if AName = 'padding-bottom' then
        Padding[csBottom] := CSSToLength(AValue)
      else
      if AName = 'padding-right' then
        Padding[csRight] := CSSToLength(AValue)
      else
      if AName = 'position' then
        Position := CSSToPosition(AValue);
    't':
      if AName = 'top' then
        Top := CSSToLength(AValue)
      else
      if AName = 'text-align' then
        TextAlign := CSSToTextAlign(AValue)
      else
      if AName = 'text-decoration' then
        Font.TextDecoration := CSSToTextDecoration(AValue);
    'h':
      if AName = 'height' then
        Height := CSSToLength(AValue);
    'w':
      if AName = 'width' then
        Width := CSSToLength(AValue);
  end;
end;

procedure TCSSItem.Assign(Source: TPersistent);
var
  Src: TCSSItem;
  I: TCSSSide;
begin
  if Source = Nil then Exit;
	if Source is TCSSItem then begin
		Src := TCSSItem(Source);
    AlignItems := Src.AlignItems;
    Background := Src.Background;
    Color := Src.Color;
    Cursor := Src.Cursor;
    Display := Src.Display;
    Font := Src.Font;
    Float := Src.Float;
    for I := Low(TCSSSide) to High(TCSSSide) do
      Border[I] := Src.Border[I];
    for I := Low(TCSSSide) to High(TCSSSide) do
      Margin[I] := Src.Margin[I];
    for I := Low(TCSSSide) to High(TCSSSide) do
      Padding[I] := Src.Padding[I];
    TextAlign :=  Src.TextAlign;
    Height := Src.Height;
    Width := Src.Width;
	end else
		inherited Assign(Source);
end;

procedure TCSSItem.Merge(AValue: TCSSItem);
var
  I: TCSSSide;
begin
  if AValue.Color.ColorType <> cctUndefined then Color := AValue.Color;
  for I := Low(TCSSSide) to High(TCSSSide) do
    if AValue.Margin[TCSSSide(I)].LengthType <> cltUndefined then Margin[csTop] := AValue.Margin[csTop];
end;

{ THtmlNode }


procedure THtmlNode.SetStyleValue(AName: String; AValue: String);
begin
  CompStyle.AddProperty(AName, AValue);
end;

function Merge(c1, c2, c3, c4: Cardinal): Cardinal; inline;
var
  r, g, b, a: Cardinal;
begin
  a := (c1 shr 24) and $ff + (c2 shr 24) and $ff + (c3 shr 24) and $ff + (c4 shr 24) and $ff;
  r := (c1 shr 16) and $ff + (c2 shr 16) and $ff + (c3 shr 16) and $ff + (c4 shr 16) and $ff;
  g := (c1 shr  8) and $ff + (c2 shr  8) and $ff + (c3 shr  8) and $ff + (c4 shr  8) and $ff;
  b := (c1       ) and $ff + (c2       ) and $ff + (c3       ) and $ff + (c4       ) and $ff;
  Result := (a shr 2) shl 24
          + (r shr 2) shl 16
          + (g shr 2) shl  8
          + (b shr 2);
end;

{$ifdef fpc}
procedure AntiAliaze(Bmp: TBitmap);
type
  TPair = record
    c1, c2 : Cardinal;
  end;
var
  w,h:Integer;
  x,y: Integer;
  p1 : PCardinal;
  p2 : ^TPair;
  p3 : ^TPair;
begin
  w := Bmp.Width div 2;
  h := Bmp.Height div 2;
  for y := 0 to h - 1 do  begin
    p1 := Bmp.ScanLine[y];
    p2 := Bmp.ScanLine[2 * y];
    p3 := Bmp.ScanLine[2 * y + 1];
    for x:= 0 to w - 1 do begin
      p1^ := Merge(p2^.c1, p2^.c2, p3^.c1, p3^.c2);
      Inc(p1);
      Inc(p2);
      Inc(p3);
    end;
  end;
  Bmp.SetSize(w, h);
end;

procedure ClearBitmap(Bmp: TBitmap);
var
  w,h:Integer;
  x,y: Integer;
  p1 : PCardinal;
begin
  w := Bmp.Width;
  h := Bmp.Height;
  Bmp.BeginUpdate();
  for y := 0 to h - 1 do  begin
    p1 := PCardinal(Bmp.RawImage.GetLineStart(y));  //Bmp.ScanLine[y];
    for x:= 0 to w - 1 do begin
//      if p1^ = 0 then
        p1^ := $a0 shl 24 OR $ff shl 16;
      Inc(p1);
    end;
  end;
  Bmp.EndUpdate();
end;
{$endif}

(*
  Function to calculate the intersectionpoints of an ellipse (x/a)^2 + (y/b)^2 = 1
  and the line y = m*x + n.
*)
function CalcIntersection(a, b, m, n: Single) : TFloatPoint; inline;
var
  D : Single;
  p, q : Single;
begin
  Result := FPoint(0,0);
  D := sqr(a * b) * (sqr(b) - sqr(n) + sqr(a * m));
  if D < 0 then exit;
  D := sqrt(D);
  p := -a * a * m * n;
  q := sqr(b) + sqr(a * m);
  Result.x := (p + D) / q;
  Result.y := m * Result.x + n;
end;

procedure THtmlNode.DrawNode(ACanvas: TCanvas; AClipRect: TRect);
var
  OPoly,              // outter poly
  IPoly: array[0..7] of TPointArray; // inner poly
  DoClip: Boolean;
  procedure RenderPolygon(TargetCanvas: TCanvas; AColor: TColor; Scale: Single; dx, dy: Integer; Points: array of TFloatPoint);
  var
    I: Integer;
    TA: array of TPoint;
  begin
    SetLength(TA, Length(Points));
    TargetCanvas.Pen.Style := psClear;
    TargetCanvas.Brush.Color := AColor;
    if (dx <> 0) or (dy <> 0) then begin // paint to tbitmap
      for I := 0 to High(Points) do begin
        Ta[I].x := Round((Points[I].x + dx) * Scale)-1;
        Ta[I].y := Round((Points[I].y + dy) * Scale)-1;
      end;
    end else
    for I := 0 to High(Points) do begin
      Ta[I].x := Round((Points[I].x + dx) * Scale);
      Ta[I].y := Round((Points[I].y + dy) * Scale);
    end;
    TargetCanvas.Polygon(Ta);
{    TargetCanvas.Pen.Style := psSolid;
    TargetCanvas.Pen.Color := AColor;
    TargetCanvas.Pen.Width := 2;
    TargetCanvas.Polyline(Ta);}
  end;

  // TODO: check if first adding point is same as last and then ignore it
  procedure AddToArray(var ATargetArray: TPointArray; const AValues: array of TFloatPoint);
  var
    Start: Integer;
    I: Integer;
  begin
    Start := Length(ATargetArray);
    SetLength(ATargetArray, Length(ATargetArray) + Length(AValues));
    for I := 0 to High(AValues) do ATargetArray[I+Start] := AValues[I];
  end;
  procedure FlipArray(var ATargetArray: TPointArray); inline;
  var
    I,L: Integer;
    T: TFloatPoint;
  begin
    L := High(ATargetArray);
    for I := 0 to High(ATargetArray) div 2 do begin
      T := ATargetArray[I];
      ATargetArray[I] := ATargetArray[L - I];
      ATargetArray[L - I] := T;
    end;
  end;

  procedure TransformArray(var ATargetArray: TPointArray; Matrix: TMatrixTransform); inline;
  var
    I: Integer;
  begin
    for I := 0 to High(ATargetArray) do  Matrix.Transform( ATargetArray[I]);
  end;

  (*

  //               ___---* - outer points
  //           __--      |
  //         _-          |
  //       /         ----|----- SECOND poly
  //     /*              |
  //    |  *             |
  //   |    *        __--* - inner points
  //  |      *     _-
  //  |       *   /
  // |         * /
  // |          *  - divider angle
  // |          |
  // |         |
  // |      ---|------ FIRST poly
  // |         |
  // *---------*
  *)

  (*
    Build corners for one border left top and right top
    B - border
    R - radius
  *)
  procedure BuildBorder(First, Second: Integer; B: TFloatPoint; R: TPoint; Matrix: TMatrixTransform); inline;
  var
    fp: TFloatPoint;
    Angle: Single;
  begin
    // outter points
    if (R.x > 0) and (R.y > 0) then begin    // outter
      if B.x = 0 then Angle := 0 else begin
        fp := CalcIntersection(R.x, R.y, B.y / B.x ,  -(((R.x / B.x) * B.y) - R.y));
        Angle :=  radtodeg( arctan2(fp.y / R.y, fp.x  / R.x));
      end;
      BuildArc(OPoly[First], Point(R.x, R.y), 180,  180 + Angle, R.x, R.y);
      BuildArc(OPoly[Second], Point(R.x, R.y), 180 + Angle, 180 + 90, R.x, R.y);
    end else begin
      AddToArray(OPoly[First], FPoint( 0, 0));
      AddToArray(OPoly[Second], FPoint( 0, 0));
    end;

    // inner points
    if (R.x > B.x) and (R.y > B.y) then begin   // inner
      if B.x = 0 then Angle := 0 else begin
         fp := CalcIntersection(R.x - B.x, R.y - B.y, B.y / B.x,  -((((R.x- B.x) / B.x) * B.y) - (R.y - B.y)));
         Angle :=  radtodeg( arctan2(fp.y / R.y, fp.x  / R.x));
      end;
      BuildArc(IPoly[First], Point(R.x , R.y), 180, 180 + Angle, R.x - B.x, R.y - B.y);
      BuildArc(IPoly[Second], Point(R.x , R.y), 180 + Angle, 180 + 90, R.x - B.x, R.y - B.y);
    end else begin
      AddToArray(IPoly[First], FPoint(B.x, B.y));
      AddToArray(IPoly[Second], FPoint(B.x, B.y));
    end;
    TransformArray(OPoly[First], Matrix);
    TransformArray(OPoly[Second], Matrix);
    TransformArray(IPoly[First], Matrix);
    TransformArray(IPoly[Second], Matrix);
  end;
  var
    cs: TCSSItem;
    Flags: Cardinal;
    R,               // temp rect
    CRect,           // content rect
    BSize: TRect;    // border rect
    RadiusTopLeft,
    RadiusTopRight,
    RadiusBottomRight,
    RadiusBottomLeft: TPoint;
    Matrix: TMatrixTransform;
    BackPoly: TPointArray;     // background poly
    BTopPoly,
    BBottomPoly,
    BLeftPoly,
    BRightPoly: TPointArray;   // border right poly
begin
  cs := FCompStyle;
  CRect := CompSize.ContentRect;
  BSize := CompSize.Border;
  RadiusTopLeft := Point( Round(CompStyle.RadiusTopLeft.Width.Value), Round(CompStyle.RadiusTopLeft.Height.Value));
  RadiusTopRight := Point(Round(CompStyle.RadiusTopRight.Width.Value), Round(CompStyle.RadiusTopRight.Height.Value));
  RadiusBottomRight := Point(Round(CompStyle.RadiusBottomRight.Width.Value), Round(CompStyle.RadiusBottomRight.Height.Value));
  RadiusBottomLeft := Point(Round(CompStyle.RadiusBottomLeft.Width.Value), Round(CompStyle.RadiusBottomLeft.Height.Value));

  SetLength(BackPoly, 0);
  SetLength(BRightPoly, 0);
  SetLength(BTopPoly, 0);
  SetLength(BBottomPoly, 0);
  SetLength(BLeftPoly, 0);


  Matrix := TMatrixTransform.Create;

  // build top left border
  Matrix.Reset.Translate(CRect.Left, CRect.Top);
  BuildBorder(0, 1, FPoint(BSize.Left, BSize.Top), Point(RadiusTopLeft.x, RadiusTopLeft.y),  Matrix);
  FlipArray(IPoly[0]);
  FlipArray(IPoly[1]);

  // build top right border
  Matrix.Reset.FlipHorizontal.Translate(CRect.Right, CRect.Top);
  BuildBorder(3, 2, FPoint(BSize.Right, BSize.Top), Point(RadiusTopRight.x, RadiusTopRight.y), Matrix);
  FlipArray(OPoly[2]);
  FlipArray(OPoly[3]);

  // build bottom right border
  Matrix.Reset.FlipHorizontal.FlipVertical.Translate(CRect.Right, CRect.Bottom);
  BuildBorder(4, 5, FPoint(BSize.Right, BSize.Bottom), Point(RadiusBottomRight.x, RadiusBottomRight.y), Matrix);
  FlipArray(IPoly[4]);
  FlipArray(IPoly[5]);

  // build bottom left border
  Matrix.Reset.FlipVertical.Translate(CRect.Left, CRect.Bottom);
  BuildBorder(7, 6, FPoint(BSize.Left, BSize.Bottom), Point(RadiusBottomLeft.x, RadiusBottomLeft.y), Matrix);
  FlipArray(OPoly[7]);
  FlipArray(OPoly[6]);
  Matrix.Free;

  ACanvas.Clipping := True;
  ACanvas.ClipRect := AClipRect;
{
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Color := clRed;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(AClipRect);
}
  // rendering part
  if cs.Background.Color.ColorType <> cctUndefined then begin
    AddToArray(BackPoly, OPoly[1]);
    AddToArray(BackPoly, OPoly[2]);
    AddToArray(BackPoly, OPoly[3]);
    AddToArray(BackPoly, OPoly[4]);
    AddToArray(BackPoly, OPoly[5]);
    AddToArray(BackPoly, OPoly[6]);
    AddToArray(BackPoly, OPoly[7]);
    AddToArray(BackPoly, OPoly[0]);
    RenderPolygon(ACanvas, cs.Background.Color.Value, 1, 0,0, BackPoly);
  end;

  if BSize.Top > 0 then begin
    AddToArray(BTopPoly, OPoly[1]);
    AddToArray(BTopPoly, OPoly[2]);
    AddToArray(BTopPoly, IPoly[2]);
    AddToArray(BTopPoly, IPoly[1]);
    RenderPolygon(ACanvas, cs.Border[csTop].Color.Value, 1, 0, 0, BTopPoly);
  end;
  if BSize.Right > 0 then begin
    AddToArray(BRightPoly, OPoly[3]);
    AddToArray(BRightPoly, OPoly[4]);
    AddToArray(BRightPoly, IPoly[4]);
    AddToArray(BRightPoly, IPoly[3]);
    RenderPolygon(ACanvas, cs.Border[csRight].Color.Value, 1, 0, 0, BRightPoly);
  end;
  if BSize.Bottom > 0 then begin
    AddToArray(BBottomPoly, OPoly[5]);
    AddToArray(BBottomPoly, OPoly[6]);
    AddToArray(BBottomPoly, IPoly[6]);
    AddToArray(BBottomPoly, IPoly[5]);
    RenderPolygon(ACanvas, cs.Border[csBottom].Color.Value, 1, 0, 0, BBottomPoly);
  end;

  if BSize.Left > 0 then begin
    AddToArray(BLeftPoly, OPoly[7]);
    AddToArray(BLeftPoly, OPoly[0]);
    AddToArray(BLeftPoly, IPoly[0]);
    AddToArray(BLeftPoly, IPoly[7]);
    RenderPolygon(ACanvas, cs.Border[csLeft].Color.Value, 1, 0, 0, BLeftPoly);
  end;
  // fine tunning with antialiasing example
{  for I := 0 to 3 do Corner[I].Req := False;
  if ((RadiusTopLeft.x > 0) and (RadiusTopLeft.y > 0)) or ((BSize.Top > 0) and (BSize.Left > 0) and (BSize.Left <> BSize.Top)) then begin
    Corner[0].Req := True;
    Corner[0].Width := Math.Max(RadiusTopLeft.x, BSize.Left) * 4;
    Corner[0].Height := Math.Max(RadiusTopLeft.y, BSize.Top) * 4;
    Corner[0].Pos := Point( CRect.Left, CRect.Top);
    FCornerBitmap[0] := TBitmap.Create;
    FCornerBitmap[0].PixelFormat :=  pf32bit;
    FCornerBitmap[0].Transparent := False;
    FCornerBitmap[0].SetSize(Corner[0].Width, Corner[0].Height);
    FCornerBitmap[0].Canvas.Brush.Color := cs.Background.Color.Value;
    RenderPolygon(FCornerBitmap[0].Canvas, 4, -CRect.Left, -CRect.Top, BackPoly);
    AntiAliaze(FCornerBitmap[0]);
    AntiAliaze(FCornerBitmap[0]);
    ACanvas.Draw(CRect.Left, CRect.Top, FCornerBitmap[0]);
    FreeAndNil(FCornerBitmap[0]);
  end;
}
  ACanvas.Pen.Style := psClear;
  // Paint Text
  if Text <> '' then begin
    ACanvas.Brush.Style := bsClear;
    {$ifdef fpc} ACanvas.Font.BeginUpdate; {$endif}
    ACanvas.Font.Style := FCompStyle.Font.Weight.Value;
    ACanvas.Font.Size := Round(FCompStyle.Font.Size.Value);
    ACanvas.Font.Color := FCompStyle.Color.Value;
    if FCompStyle.Font.TextDecoration = ctdUnderline then ACanvas.Font.Style := ACanvas.Font.Style + [fsUnderline];
    {$ifdef fpc} ACanvas.Font.EndUpdate;{$endif}
    R := Rect(FCompSize.MarginRect.Left + FCompSize.LeftSpace,
      FCompSize.MarginRect.Top + FCompSize.TopSpace,
      FCompSize.MarginRect.Right - FCompSize.RightSpace,
      FCompSize.MarginRect.Bottom - FCompSize.BottomSpace);
    Flags := DT_LEFT or  DT_NOPREFIX or DT_END_ELLIPSIS;
    case CompStyle.TextAlign of
      ctaCenter: Flags := Flags or DT_CENTER;
      ctaRight: Flags := Flags or DT_RIGHT;
    end;
    R.Intersect(AClipRect);
    DrawText(ACanvas.Handle, PChar(Text), Length(Text),  R, Flags);
{      ACanvas.Pen.Style := psSolid;
      ACanvas.Pen.Color := clFuchsia;
      ACanvas.Rectangle(Self.ParentNode.CompSize.ContentRect);
      ACanvas.Pen.Color := clGreen;
      ACanvas.Rectangle(R);
}

  end;
  if CSS_DEBUG_MODE then begin
    ACanvas.Pen.Style := psDot;
    ACanvas.Pen.Color := clRed;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Rectangle(FCompSize.MarginRect);

    ACanvas.Pen.Color := clBlue;
    ACanvas.Rectangle(FCompSize.ContentRect);

    ACanvas.Pen.Style := psSolid;
    ACanvas.Pen.Color := clFuchsia;
    ACanvas.Rectangle(CRect.Left, FCompSize.MarginRect.Bottom -  CompSize.BaseLine, CRect.Right,  FCompSize.MarginRect.Bottom - CompSize.BaseLine + 2);
   end;
end;

procedure THtmlNode.CalculateSize(out AWidth, AHeight, ABaseLine: Integer);
var
  b: TBitmap;
  ts: TSize;
begin
  if (AlignControl <> nil) then begin
    AlignControl.GetPreferredSize(AWidth, AHeight);
    if not AlignControl.AutoSize then AWidth := -1;
    ABaseLine := Round( AHeight / 5);
    Exit;
  end;

  if (FText = '') and (Element <> 'span')  then begin
    AWidth := -1;
    AHeight := -1;
    ABaseLine := 0;
    Exit;
  end;

  // TODO: maybe faster cache validation
  if (FCachedFont.Size.Value = FCompStyle.Font.Size.Value) and (FCachedFont.CachedText = Text)
    and (FCachedFont.Weight.Value = FCompStyle.Font.Weight.Value) then
  else begin
    b := TBitmap.Create;
    try
      b.Canvas.Font.Size := Round(FCompStyle.Font.Size.Value);
      b.Canvas.Font.Style := FCompStyle.Font.Weight.Value;
      ts := b.Canvas.TextExtent(Text);
      FCachedFont.CachedWidth := ts.Width + 1; // to prevent "bold" size bug
      FCachedFont.CachedHeight := ts.Height;
      FCachedFont.CachedBaseLine := Round(ts.Height/5); // TODO: get real baseline from font
      FCachedFont.Size.Value := FCompStyle.Font.Size.Value;
      FCachedFont.Weight.Value := FCompStyle.Font.Weight.Value;
      FCachedFont.CachedText := Text;
    finally
      b.Free;
    end;
  end;
  AWidth := FCachedFont.CachedWidth;
  AHeight := FCachedFont.CachedHeight;
  ABaseLine := FCachedFont.CachedBaseLine;
end;

constructor THtmlNode.Create(AInlineStyle: String = '');
var
  I: Integer;
begin
  FCompStyle := TCSSItem.Create;
  FCompSize := THtmlSize.Create;
  FClassList := TCSSClassList.Create;
  FCachedFont.Size.Value := -1;
  for I := 0 to 3 do FCornerBitmap[I] := Nil;
  RootNode := Self;
  FElementName := 'div';    // default
  FFreeMe := True;
  FText := '';
  FInlineStyle := AInlineStyle;
  FCompStyle.Parse(FInlineStyle);
end;

destructor THtmlNode.Destroy;
var
  I: Integer;
begin
  Clear;
  for I := 3 downto 0 do
    if FCornerBitmap[I] <> Nil then FCornerBitmap[I].Free;
  FClassList.Free;
  FCompSize.Free;
  FCompStyle.Free;
  inherited Destroy;
end;

procedure THtmlNode.Assign(Source: TPersistent);
var
  Src: THtmlNode;
begin
  if Source is THtmlNode then begin
    Src := THtmlNode(Source);
    Element := Src.Element;
    Id := Src.Id;
    InlineStyle := Src.InlineStyle;
    AlignControl := Src.AlignControl;
  end else
    inherited Assign(Source);
end;

function THtmlNode.ApplyStyle: THtmlNode;
begin
  Result := Self;
  ApplyStyleForNode(Self);
end;

function THtmlNode.ApplyStyles: THtmlNode;
  procedure ApplyInside(ANode: THtmlNode);
  begin
    while Assigned(ANode) do begin
      ApplyStyleForNode(ANode);
      if ANode.ChildCount > 0 then ApplyInside(ANode.FirstChild);
      ANode := ANode.GetNext(ANode, False);
    end;
  end;
begin
  Result := Self;
  ApplyInside(Self);
end;

(*
  Apply style to selected node, slow parsing text each time.
*)
procedure THtmlNode.ApplyStyleForNode(ANode: THtmlNode);
var
  sh: TCSSStyleSheet;
  s: String;
  I: Integer;
begin
  if ANode.RootNode = Nil then exit;
  sh := ANode.RootNode.StyleSheet;
  ANode.FCompStyle.Reset;
  if ANode.FElementName = 'span' then ANode.FCompStyle.Display := cdtInline;    //TODO: better solution here
  if Assigned(sh) then begin // if we have defined StyleSheet
    for I := 0 to ANode.ClassList.Count -1 do begin
      s := '.' + ANode.ClassList.Item[I];
      ANode.FCompStyle.ParseFromStyleSheet(sh, s);
      if ANode.FPrevSibling = nil then ANode.FCompStyle.ParseFromStyleSheet(sh, s+':first-child');
      if ANode.FNextSibling = nil then ANode.FCompStyle.ParseFromStyleSheet(sh, s+':last-child');
      if ANode.Hovered then begin
        ANode.FCompStyle.ParseFromStyleSheet(sh, s+':hover');
        if ANode.FPrevSibling = nil then ANode.FCompStyle.ParseFromStyleSheet(sh, s+':first-child:hover');
        if ANode.FNextSibling = nil then ANode.FCompStyle.ParseFromStyleSheet(sh, s+':last-child:hover');
      end;
    end;
  end;
  if ANode.InlineStyle <> '' then  ANode.FCompStyle.Parse(ANode.InlineStyle);
  if (ANode.Hovered) and (ANode.HoverStyle <> '') then ANode.FCompStyle.Parse(HoverStyle);
end;

procedure THtmlNode.PaintTo(ACanvas: TCanvas);
  procedure RenderNode(Node: THtmlNode; ClipRect: TRect);
  begin
    while Assigned(Node) do begin
      if Node.FVisible then Node.DrawNode(ACanvas, ClipRect);
      if Node.ChildCount > 0 then begin
        if Node.CompStyle.Overflow = cotHidden then
          RenderNode(Node.FirstChild, Node.CompSize.RealContentRect) // Note: this is not CSS standard behavior use Node.CompSize.ContentRect;
        else
          RenderNode(Node.FirstChild, ClipRect)
      end;
      Node := GetNext(Node, False);
    end;
  end;
begin
  RenderNode(Self, Rect(0,0, {ACanvas.Width} MaxInt, {ACanvas.Height} MaxInt));
end;

function THtmlNode.SetAlignControl(AValue: TControl): THtmlNode;
begin
  Result := Self;
  FAlignControl := AValue;
end;

(*
  Space separated
*)
function THtmlNode.SetClass(AValues: String): THtmlNode;
begin
  Result := Self;
  FClassList.Name := AValues;
end;


(*
  Align all nodes on same line based on base line and return max bottom
  https://developer.mozilla.org/en-US/docs/Web/CSS/vertical-align
  TODO: Add support for various vertical-align
*)
function THtmlNode.LayoutDoVerticalAlign(AList: TList; ClearList: Boolean = True): Integer;
var
  Dif,
  mI: Integer;
  Item: THtmlNode;
  MinMargin,
  MaxBaseLine: Integer;
begin
  MaxBaseLine := 0;
  Result := 0;
  MinMargin := MaxInt;
  for mI := 0 to AList.Count-1 do begin
    Item := THtmlNode(AList.Items[mI]);
    if Item.CompStyle.Position <> cpAbsolute then  begin
      MaxBaseLine := Max(MaxBaseLine, Item.FCompSize.MarginRect.Bottom -  Item.FCompSize.BaseLine - Item.FCompSize.Position.Top);
      MinMargin := Math.Min(MinMargin, Item.CompSize.MarginRect.Top);
    end;
  end;
  if MinMargin = MaxInt then MinMargin := 0;;
  for mI := 0 to AList.Count-1 do begin                 // realign top and bottom of all controls
    Item := THtmlNode(AList.Items[mI]);

    if Item.CompStyle.Position = cpAbsolute then Continue;
    if Item.FCompSize.MarginRect.Bottom - Item.FCompSize.BaseLine - Item.FCompSize.Position.Top < MaxBaseLine then begin
      Dif := MaxBaseLine - (Item.FCompSize.MarginRect.Bottom - Item.FCompSize.BaseLine - Item.FCompSize.Position.Top);
      Inc(Item.FCompSize.ContentRect.Top, Dif);
      Inc(Item.FCompSize.ContentRect.Bottom, Dif);
      Inc(Item.FCompSize.MarginRect.Top, Dif);
      Inc(Item.FCompSize.MarginRect.Bottom, Dif);
    end;
    Result := Math.Max(Result, Item.CompSize.MarginRect.Bottom - MinMargin);
  end;
  if ClearList then AList.Clear;
end;

procedure THtmlNode.LayoutGetNodeSize(ANode: THtmlNode; ParentWidth, ParentHeight: Integer; InFlex: Boolean = False);
var
  childWidth,
  childHeight,
  cW, cH, cB: Integer;
  R: TRect;
  cs: TCSSItem;
begin

  cs := ANode.FCompStyle;
  if (ANode.FCompStyle.Font.Weight.FontType = cfwBold) then
    ANode.FCompStyle.Font.Weight.Value := [fsBold] else
  if Assigned(ANode.ParentNode) then
    ANode.FCompStyle.Font.Weight.Value := ANode.ParentNode.FCompStyle.Font.Weight.Value
  else
    ANode.FCompStyle.Font.Weight.Value := [];

  // inherit parent style here
  // font style inherit
  if (ANode.FCompStyle.TextAlign = ctaUndefined) and (ANode.ParentNode <> Nil) then
      ANode.FCompStyle.TextAlign := ANode.ParentNode.CompStyle.TextAlign;

  if (ANode.FCompStyle.Font.TextDecoration = ctdUndefined) then begin
    if (Assigned(ANode.ParentNode)) then
      ANode.FCompStyle.Font.TextDecoration := ANode.ParentNode.FCompStyle.Font.TextDecoration
    else
      ANode.FCompStyle.Font.TextDecoration := ctdNone;
  end;
  if ANode.FCompStyle.Color.ColorType = cctUndefined then begin
    if Assigned(ANode.ParentNode) then
      ANode.FCompStyle.Color.Value := ANode.ParentNode.CompStyle.Color.Value
    else ANode.FCompStyle.Color.Value := clBlack;
  end;
  if (Assigned(ANode.ParentNode)) and (ANode.FCompStyle.Font.Size.LengthType = cltUndefined) then
    ANode.FCompStyle.Font.Size.Value := ANode.ParentNode.CompStyle.Font.Size.Value;

  ANode.FCompSize.Position.Left := CalcCSSLength(cs.Left, ParentWidth);
  ANode.FCompSize.Position.Top := CalcCSSLength(cs.Top, ParentHeight);

  // margins
  R.Top := CalcCSSLength(cs.Margin[csTop], ParentHeight);
  R.Left := CalcCSSLength(cs.Margin[csLeft], ParentWidth);
  R.Right := CalcCSSLength(cs.Margin[csRight], ParentWidth);
  R.Bottom := CalcCSSLength(cs.Margin[csBottom], ParentHeight);
  ANode.FCompSize.Margin := R;

  R.Top := CalcCSSLength(cs.Padding[csTop], ParentWidth);
  R.Left := CalcCSSLength(cs.Padding[csLeft], ParentWidth);
  R.Right := CalcCSSLength(cs.Padding[csRight], ParentWidth);
  R.Bottom := CalcCSSLength(cs.Padding[csBottom], ParentWidth);
  ANode.CompSize.Padding := R;

  R.Top := CalcCSSLength(cs.Border[csTop].Width, ParentWidth);
  R.Left := CalcCSSLength(cs.Border[csLeft].Width, ParentWidth);
  R.Right := CalcCSSLength(cs.Border[csRight].Width, ParentWidth);
  R.Bottom := CalcCSSLength(cs.Border[csBottom].Width, ParentWidth);
  ANode.CompSize.Border := R;

  ANode.CalculateSize(cW, cH, cB);      // return -1, -1, 0 if node doesn't have own sizes. TextNode have own size (text size)
  // if width/height is set in this node owerrite
  case cs.Width.LengthType of
    cltPercentage: if ParentWidth <> -1 then cW := Round((ParentWidth/100) * cs.Width.Value);
    cltPx:         cW := Round(cs.Width.Value);
    cltUndefined:  if (ParentWidth <> -1) and ((cs.Display in [cdtBlock,cdtFlex]) and (not InFlex) and not( cs.Float  in [cftLeft, cftRight])) then
      cW := ParentWidth - ANode.CompSize.LeftSpace - ANode.CompSize.RightSpace;
  end;
  // height
  case cs.Height.LengthType of
    cltPercentage:  if ParentHeight <> -1 then cH := Round((ParentHeight/100) * cs.Height.Value);
    cltPx:          cH := Round(cs.Height.Value);
{    cltUndefined:   if (cs.Display = cdtBlock) and (cH = -1) and (ANode.ChildCount = 0) and not( cs.Float  in [cftLeft, cftRight]) then
      cH := ParentHeight - ANode.FCompSize.Margin.Top - ANode.FCompSize.Margin.Bottom;
}
  end;
  // if node have childrens calculate childrens required space
  if ANode.FChildCount > 0 then begin
    if (cs.Display in [cdtBlock, cdtFlex]) and (cW = -1) {and (not InFlex)} then
      cW := ParentWidth;
    LayoutCalcPosition(ANode.FFirstChild, cW, cH, childWidth, childHeight);
    if InFlex then cW := -1;
    if cW = -1 then cW := childWidth;
    if cH = -1 then cH := childHeight;
    cB := cH - ANode.FLastNode.CompSize.MarginRect.Bottom + ANode.FLastNode.CompSize.BaseLine + ANode.CompSize.BottomSpace; // TODO: not LastNode, but bottom right position node
  end else
    if cB > 0 then cB := cB + ANode.FCompSize.Padding.Bottom + ANode.FCompSize.Border.Bottom  + ANode.FCompSize.Margin.Bottom;
  if cW = -1 then cW := 0;
  if cH = -1 then cH := 0;
  Inc(cW, ANode.CompSize.Padding.Left + ANode.CompSize.Padding.Right +  ANode.CompSize.Border.Left + ANode.CompSize.Border.Right);
  Inc(cH, ANode.CompSize.Padding.Top + ANode.CompSize.Padding.Bottom + ANode.CompSize.Border.Top + ANode.CompSize.Border.Bottom);
  ANode.FCompSize.BaseLine := cB;
  ANode.FCompSize.ContentWidth := cW;
  ANode.FCompSize.ContentHeight := cH;

end;


procedure THtmlNode.LayoutDoFlexAlign(AParentNode: THtmlNode; AList: TList; AWidth, AHeight: Integer);
var
  SumFlexGrow: Single;
  NewWidth, NewHeight,
  X,Y: Integer;
  CountFlexGrow,
  I: Integer;
  Node: THtmlNode;
  UsedSpace,
  MaxBaseline,
  MaxSize: Integer; // width or height
begin
  // only one row is supported now
  SumFlexGrow := 0;
  CountFlexGrow := 0;
  UsedSpace := 0;
  // calculate used space and try to get sizes
  for I := 0 to AList.Count -1 do begin
   Node := THtmlNode(AList.Items[I]);

   LayoutGetNodeSize(Node, AWidth,  AHeight, True);
   if Node.CompStyle.Position = cpAbsolute then Continue;      // skip nodes with absolute position
   if Node.CompStyle.FlexGrow > 0 then begin
     SumFlexGrow := SumFlexGrow + Node.CompStyle.FlexGrow;
     Inc(CountFlexGrow);
   end;
   Inc(UsedSpace, Node.CompSize.ContentWidth + Node.CompSize.Margin.Left + Node.CompSize.Margin.Right);
  end;

  // calculate max size (height only just now) and make second iteration for nodes layout
  MaxSize := 0;
  MaxBaseline := 0;
  for I := 0 to AList.Count -1 do begin
    Node := THtmlNode(AList.Items[I]);
    if Node.CompStyle.Position <> cpAbsolute then begin
      if Node.CompStyle.FlexGrow > 0 then
        LayoutGetNodeSize(Node, Node.CompSize.ContentWidth - Node.CompSize.Padding.Right - Node.CompSize.Padding.Left - Node.CompSize.Border.Left - Node.CompSize.Border.Right { + Node.CompSize.Margin.Left + Node.CompSize.Margin.Right } +  Round(((AWidth - UsedSpace) / SumFlexGrow) * Node.CompStyle.FlexGrow), AHeight, True);
      MaxSize := Math.Max(MaxSize, Node.CompSize.ContentHeight + Node.CompSize.Margin.Top + Node.CompSize.Margin.Bottom);
      if Node.CompStyle.Position <> cpAbsolute then  MaxBaseLine := Max(MaxBaseLine, Node.FCompSize.MarginRect.Bottom -  Node.FCompSize.BaseLine - Node.FCompSize.Position.Top);
    end;
  end;

  // align position based on vertical align (content just now)
  X := 0;
  Y := 0;
  for I := 0 to AList.Count -1 do begin
    Node := THtmlNode(AList.Items[I]);
    if Node.CompStyle.Position = cpAbsolute then begin
      Node.CompSize.MarginRect := Rect( Node.CompSize.Position.Left, Node.CompSize.Position.Top,
        Node.CompSize.Position.Left + Node.CompSize.ContentWidth + Node.CompSize.Margin.Left + Node.CompSize.Margin.Right,
        Node.CompSize.Position.Top + Node.CompSize.ContentHeight + Node.CompSize.Margin.Top + Node.CompSize.Margin.Bottom);
      Node.CompSize.ContentRect := Rect(Node.CompSize.MarginRect.Left + Node.CompSize.Margin.Left, Node.CompSize.MarginRect.Top + Node.CompSize.Margin.Top,
        Node.CompSize.MarginRect.Right - Node.CompSize.Margin.Right, Node.CompSize.MarginRect.Bottom - Node.CompSize.Margin.Bottom
      );
    end else
    begin
      // TODO: fine align node due ROUND
      if Node.CompStyle.FlexGrow > 0 then begin
        NewWidth := Math.Max(Node.CompSize.ContentWidth , Node.CompSize.ContentWidth + Node.CompSize.Margin.Left + Node.CompSize.Margin.Right +  Round(((AWidth - UsedSpace) / SumFlexGrow) * Node.CompStyle.FlexGrow));
      end
      else
        NewWidth := Node.CompSize.ContentWidth + Node.CompSize.Margin.Left + Node.CompSize.Margin.Right;
      if AParentNode.CompStyle.AlignItems = caiStretch then begin
        NewHeight := MaxSize;
        Node.CompSize.MarginRect := Rect(X, Y,  X + NewWidth, Y + NewHeight);
        Node.CompSize.ContentRect := Rect(Node.CompSize.MarginRect.Left + Node.CompSize.Margin.Left, Node.CompSize.MarginRect.Top + Node.CompSize.Margin.Top,
          Node.CompSize.MarginRect.Right - Node.CompSize.Margin.Right, Node.CompSize.MarginRect.Bottom - Node.CompSize.Margin.Bottom
        );
      end
      else begin // baseline
        Node.CompSize.MarginRect := Rect(X, Y,  X + NewWidth, Y + Node.CompSize.Margin.Top + Node.CompSize.ContentHeight + Node.CompSize.Margin.Bottom);
        Node.CompSize.ContentRect := Rect(Node.CompSize.MarginRect.Left + Node.CompSize.Margin.Left, Node.CompSize.MarginRect.Top + Node.CompSize.Margin.Top ,
          Node.CompSize.MarginRect.Right - Node.CompSize.Margin.Right, Node.CompSize.MarginRect.Bottom - Node.CompSize.Margin.Bottom
        );
      end;
      Inc(X, Node.CompSize.MarginRect.Width);
    end;
  end;
  if AParentNode.CompStyle.AlignItems = caiBaseline then begin
    MaxSize := LayoutDoVerticalAlign(AList, False);
{    MaxSize := 0;
    for I := 0 to AList.Count -1 do
      MaxSize := Math.Max(MaxSize, THtmlNode(AList.Items[I]).CompSize.MarginRect.Bottom);
}
  end;
  AParentNode.CompSize.ContentWidth := x;             // set new size for parent node
  AParentNode.CompSize.ContentHeight := Y + MaxSize;
end;

procedure THtmlNode.LayoutCalcPosition(ANode: THtmlNode; TargetWidth, TargetHeight: Integer; out NewWidth, NewHeight: Integer);
var
  INode,
  ForNode: THtmlNode;
  IterationCounter: Integer;
  NeedIteration: Boolean;
  PrefWidth, PrefHeight,
  Dx, Dy: Integer;
  LeftOffset,
  RightOffset: TPoint; // offsets for float:left and float:right
  RowHeight: Integer;
  RealMargin,
  ContentBounds: TRect;
  cs: TCSSItem;
  GapList: TList;
  ParentIsFlex: Boolean;
begin
  ForNode := ANode;   // backup node
  ParentIsFlex := (ANode.ParentNode <> nil) and (ANode.ParentNode.FCompStyle.Display in [cdtFlex, cdtInlineFlex]);
  if ParentIsFlex then begin // display mode flex
    INode := ANode;
    GapList := TList.Create;
    while Assigned(INode) do begin
      GapList.Add(INode);
      INode := INode.GetNext(INode);
    end;

    LayoutDoFlexAlign(ANode.ParentNode, GapList, TargetWidth, TargetHeight);
    GapList.Free;
    NewWidth := ANode.ParentNode.CompSize.ContentWidth;
    NewHeight := ANode.ParentNode.CompSize.ContentHeight;
    Exit;
  end;

  GapList := TList.Create;
  IterationCounter := 0;
  NewWidth := 0;
  NewHeight := 0;
  repeat
    ANode := ForNode;
    Dx := 0;
    Dy := 0;
    LeftOffset := Point(0,0);     // for float:left ?
    RightOffset := Point(0,0);    // for float:right ?
    RowHeight := 0;
    NeedIteration := False;
    while Assigned(ANode) do begin
      if ANode.FCompStyle.Display = cdtNone then begin
        ANode := ANode.GetNext(ANode, False);
        Continue;
      end;
      cs := ANode.FCompStyle;
      // we can't compute ContentWidth or ContentHeight (eg.: first node width:90% but targetwith is unknown yet (will be known after next iteration)
      if ((TargetWidth = -1) and (ANode.CompStyle.Width.LengthType = cltPercentage)) or
        ((TargetHeight = -1) and (ANode.CompStyle.Height.LengthType = cltPercentage)) then begin
        Dx := 0;
        Dy := 0;
        NeedIteration := True
      end
      else begin
        LayoutGetNodeSize(ANode, TargetWidth, TargetHeight); // TODO: this is correct size??
        PrefWidth := ANode.FCompSize.ContentWidth;
        PrefHeight := ANode.FCompSize.ContentHeight;
        RealMargin := ANode.FCompSize.Margin;
        // if we are using auto margins set it to zero
        if RealMargin.Left = MaxInt then RealMargin.Left := 0;
        if RealMargin.Top = MaxInt then RealMargin.Top := 0;
        if RealMargin.Right = MaxInt then RealMargin.Right := 0;
        if RealMargin.Bottom = MaxInt then RealMargin.Bottom := 0;
        if cs.Position = cpAbsolute then
          ContentBounds := Rect(Dx + RealMargin.Left, Dy + RealMargin.Top, Dx + PrefWidth + RealMargin.Left, Dy + PrefHeight + RealMargin.Top)
        else begin
          if (cs.Display in [cdtInline, cdtInlineFlex]) or (cs.Float in [cftLeft, cftRight]) then begin
            if (TargetWidth =-1) or ((Dx + PrefWidth + RealMargin.Left + RealMargin.Right) <= (TargetWidth - RightOffset.x)) then begin
              ContentBounds := Rect(Dx, Dy, Dx + PrefWidth, Dy + PrefHeight);
              RowHeight := Max(PrefHeight + RealMargin.Top + RealMargin.Bottom, RowHeight);
              Inc(Dx, PrefWidth);
            end else begin // there is no space in current "line" move to next
              RowHeight :=  LayoutDoVerticalAlign(GapList);
              Inc(Dy, RowHeight);
              RowHeight := PrefHeight + RealMargin.Top + RealMargin.Bottom;
              if Dy > LeftOffset.y then  LeftOffset.x := 0;
              Dx := LeftOffset.x;
              ContentBounds := Rect(Dx, Dy, Dx + PrefWidth, Dy + PrefHeight);
              Inc(Dx, PrefWidth);
            end;
            GapList.Add(ANode);
            Inc(ContentBounds.Left, RealMargin.Left);
            Inc(ContentBounds.Right, RealMargin.Left);
            Inc(Dx, RealMargin.Right);
            Inc(Dx, RealMargin.Left);
          end else begin    // block display: node use whole available space
            LayoutDoVerticalAlign(GapList);
            if (Dx > 0) and (LeftOffset.x = 0) then Inc(Dy, RowHeight);
            Dx := 0 + RealMargin.Left;
            ContentBounds := Rect(Dx, Dy, Dx + PrefWidth , Dy + PrefHeight); // new bounds  before margins
            RowHeight := 0;
            Inc(Dy, PrefHeight + RealMargin.Top + RealMargin.Bottom);
            Dx := 0;
          end;

          Inc(ContentBounds.Top, RealMargin.Top);
          Inc(ContentBounds.Bottom, RealMargin.Top);
          if  (ANode.CompStyle.Width.LengthType in [cltPx, cltPt, cltEm, cltUndefined]) then
            NewWidth := Max(NewWidth, ContentBounds.Right+RealMargin.Right); // only specified nodes is counted to width
          NewHeight := Max(NewHeight, ContentBounds.Bottom + RealMargin.Bottom);

        end;
        ANode.FCompSize.ContentRect := ContentBounds;
        ANode.FCompSize.MarginRect.TopLeft := Point(ANode.FCompSize.ContentRect.Left - ANode.FCompSize.Margin.Left, ANode.FCompSize.ContentRect.Top - ANode.FCompSize.Margin.Top);
        ANode.FCompSize.MarginRect.BottomRight := Point(ANode.FCompSize.ContentRect.Right + ANode.FCompSize.Margin.Right, ANode.FCompSize.ContentRect.Bottom + ANode.FCompSize.Margin.Bottom);
        if cs.Float = cftLeft then LeftOffset.x := Dx;
        RowHeight := Max(RowHeight, PrefHeight);
      end;
      ANode := ANode.GetNext(ANode, False);
    end;
    LayoutDoVerticalAlign(GapList);
    if ForNode.FCompSize.ContentWidth = MaxInt then ForNode.FCompSize.ContentWidth := NewWidth;
    if ForNode.FCompSize.ContentHeight = MaxInt then ForNode.FCompSize.ContentHeight := NewHeight;
    if TargetWidth =-1 then TargetWidth := NewWidth;
    if TargetHeight =-1 then TargetHeight := NewHeight;
    Inc(IterationCounter);
  until not NeedIteration;

  // adjust nodes after NewWidth of node is calculated for all sibling nodes
  ANode := ForNode;
//  if ForNode.CompStyle.Width.LengthType = cltPx then NewWidth := Round(ForNode.CompStyle.Width.Value);
  while Assigned(ANode) do begin
    if ANode.CompStyle.Display in [cdtBlock, cdtFlex] then begin
      if ANode.CompStyle.Width.LengthType = cltUndefined then begin // fix block alignment  (eg. first node is block and next is inline, and block width is not correct)
        ANode.FCompSize.MarginRect.Right := TargetWidth;
        ANode.FCompSize.ContentRect.Right := ANode.FCompSize.MarginRect.Right - ANode.CompSize.Margin.Right;
      end;
    end;
    if (ANode.CompStyle.Position in [cpRelative,cpAbsolute]) then begin
      OffsetRect( ANode.FCompSize.MarginRect, ANode.FCompSize.Position.Left, ANode.FCompSize.Position.Top);
      OffsetRect( ANode.FCompSize.ContentRect, ANode.FCompSize.Position.Left, ANode.FCompSize.Position.Top);
    end;
    ANode := ANode.GetNext(ANode, False);
  end;
  GapList.Free;
end;

(*
  Calculate layout size based on target Rect
  Logic:
  - first go trought all nodes and find Width/Height/Margins for nodes with fixed or defined values CalcSize(Self, ARect.Width, ARect.Height);
  - next step is calculate real content rect and calculate remaining width/height based on chlidren width/height SetPosition(Self, ARect);
  - loop until all nodes have valid sizes
  - last is Controls alignment if AAlignControls is set
*)

procedure THtmlNode.LayoutTo(ALeft, ATop, AWidth, AHeight: Integer; AAlignControls: Boolean = False);
var
  TempWidth, TempHeight: Integer;
  CtrlNode: THtmlNode; // for align controls
  CtrlOldBounds, CtrlNewBounds: TRect;
  (*
    Adjust positions and set visible status based on parents nodes
  *)
  procedure AdjustPosition(ANode: THtmlNode; StartX, StartY: Integer; ParentVisible: Boolean);
  var
    Dx, Dy: Integer;
  begin
    while Assigned(ANode) do begin
      ANode.FVisible := (ANode.FCompStyle.Display <> cdtNone) and (ParentVisible);
      if ANode.FVisible then begin
        Dx := 0;
        Dy := 0;
        if (ANode.CompStyle.Margin[csLeft].LengthType = cltAuto) and (ANode.ParentNode <> Nil) then
          Dx := (ANode.ParentNode.CompSize.RealContentWidth - ANode.CompSize.ContentWidth) div 2;
        OffsetRect(ANode.FCompSize.ContentRect, StartX + Dx, StartY + Dy);
        OffsetRect(ANode.FCompSize.MarginRect, StartX + Dx, StartY + Dy);
      end;
      if ANode.FChildCount > 0 then
        AdjustPosition(ANode.FFirstChild, ANode.FCompSize.ContentRect.Left + ANode.FCompSize.Padding.Left + ANode.FCompSize.Border.Left,
          ANode.FCompSize.ContentRect.Top + ANode.FCompSize.Padding.Top + ANode.FCompSize.Border.Top, ANode.FVisible);
      ANode := ANode.GetNext(ANode, False);
    end;
  end;
{
  var
    iFrequency, iTimerStart, iTimerEnd: Int64;
}
begin
//	QueryPerformanceFrequency(iFrequency);
//	QueryPerformanceCounter(iTimerStart);

//  Writeln(Awidth, ' - ' , AHeight);

  //TODO: correct calculation needed here
  Self.CompSize.Margin.Left := CalcCSSLength(Self.CompStyle.Margin[csLeft], AWidth);
  Self.CompSize.Margin.Right := CalcCSSLength(Self.CompStyle.Margin[csRight], AWidth);
  Self.CompSize.Margin.Top := CalcCSSLength(Self.CompStyle.Margin[csTop], AHeight);
  Self.CompSize.Margin.Bottom := CalcCSSLength(Self.CompStyle.Margin[csBottom], AHeight);

  Self.CompSize.Padding.Left := CalcCSSLength(Self.CompStyle.Padding[csLeft], AWidth);
  Self.CompSize.Padding.Right := CalcCSSLength(Self.CompStyle.Padding[csRight], AWidth);
  Self.CompSize.Padding.Top := CalcCSSLength(Self.CompStyle.Padding[csTop], AHeight);
  Self.CompSize.Padding.Bottom := CalcCSSLength(Self.CompStyle.Padding[csBottom], AHeight);

  Self.CompSize.Border.Left := CalcCSSLength(Self.CompStyle.Border[csLeft].Width, AWidth);
  Self.CompSize.Border.Right := CalcCSSLength(Self.CompStyle.Border[csRight].Width, AWidth);
  Self.CompSize.Border.Top := CalcCSSLength(Self.CompStyle.Border[csTop].Width, AHeight);
  Self.CompSize.Border.Bottom := CalcCSSLength(Self.CompStyle.Border[csBottom].Width, AHeight);

   // override "body" and ignore set width or height value
  if AWidth = -1 then begin
{    if Self.CompStyle.Width.LengthType = cltPercentage then}
      Self.CompStyle.Width.LengthType := cltUndefined;
  end
  else begin
    Self.CompStyle.Width.LengthType := cltPx;
    Self.CompStyle.Width.Value := AWidth - Self.CompSize.LeftSpace - Self.CompSize.RightSpace;
  end;
  if AHeight = -1 then begin
    Self.CompStyle.Height.LengthType := cltUndefined;
  end
  else begin
    Self.CompStyle.Height.LengthType := cltPx;
    Self.CompStyle.Height.Value := AHeight - Self.CompSize.TopSpace - Self.CompSize.BottomSpace;
  end;

  if not AAlignControls then begin
    LayoutCalcPosition(Self, AWidth, AHeight, TempWidth, TempHeight);
    AdjustPosition(Self, ALeft, ATop, True);
    Exit;
  end;
  //QueryPerformanceCounter(iTimerEnd);
  //  WriteLn( FloatToStr( 1000 * ((iTimerEnd - iTimerStart) / ifrequency)));
//  if not AAlignControls then Exit;

  // do this only for aligned controls
  if Self.RootNode.FParentControl <> Nil then begin
    TempWidth := Self.RootNode.FParentControl.Left;
    TempHeight := Self.RootNode.FParentControl.Top;
  end else begin
    TempWidth := 0;
    TempHeight := 0;
  end;
  CtrlNode := Self;
  while Assigned(CtrlNode) do begin
    CtrlNode.CompStyle.Changed := False;
    if CtrlNode.AlignControl <> Nil then begin
      if not CtrlNode.FVisible then begin    // hide assigned control if owner node is invisible
        if CtrlNode.AlignControl.Visible then begin
          CtrlNode.FAlignControlWasHidden := True;
          CtrlNode.AlignControl.Visible := False;
        end
      end else begin
        if CtrlNode.FAlignControlWasHidden then begin
          CtrlNode.FAlignControlWasHidden := False;
          CtrlNode.AlignControl.Visible := True;
        end;
      end;
      CtrlNode.AlignControl.BringToFront;
      CtrlOldBounds := CtrlNode.AlignControl.BoundsRect;
      CtrlNewBounds := Rect(
        CtrlNode.FCompSize.ContentRect.Left + CtrlNode.FCompSize.Border.Left + CtrlNode.FCompSize.Padding.Left,
        CtrlNode.FCompSize.ContentRect.Top  + CtrlNode.FCompSize.Padding.Top + CtrlNode.FCompSize.Border.Top,
        CtrlNode.FCompSize.ContentRect.Right - CtrlNode.FCompSize.Border.Right - CtrlNode.FCompSize.Padding.Right,
        CtrlNode.FCompSize.ContentRect.Bottom - CtrlNode.FCompSize.Border.Bottom - CtrlNode.FCompSize.Padding.Bottom
      );
      OffsetRect(CtrlNewBounds, TempWidth, TempHeight);
      if (CtrlNode.AlignControl.Parent <> nil) and (not CompareRect(@CtrlNewBounds,@CtrlOldBounds)) then begin
			  CtrlNode.AlignControl.SetBounds(
				  CtrlNewBounds.Left,
				  CtrlNewBounds.Top,
				  CtrlNewBounds.Right - CtrlNewBounds.Left,
				  CtrlNewBounds.Bottom - CtrlNewBounds.Top
			  );
      end;
    end;
    CtrlNode := CtrlNode.GetNext(CtrlNode, True);
  end;
end;

(*
  Get Last node at position with OnClick
*)
function THtmlNode.NodeAtPosition(APos: TPoint): THtmlNode;
var
  Node: THtmlNode;
begin
  Node := Self;
  Result := Nil;
  while Assigned(Node) do begin
    if PtInRect(Node.CompSize.ContentRect, APos) then begin
      if Node.FOnClick <> Nil then Result := Node;
      if Node.ChildCount > 0 then begin
        Node := Node.FFirstChild; // go inside
        Continue;
      end;
    end;
    Node := Node.GetNext(Node, False);
  end;
end;

function THtmlNode.SetInline(AValue: String): THtmlNode;
begin
  Result := Self;
  InlineStyle := AValue;
end;

function THtmlNode.SetId(AValue: String): THtmlNode;
begin
  Result := Self;
  FId := AValue;
end;

function THtmlNode.SetHover(AValue: String): THtmlNode;
begin
  Result := Self;
  HoverStyle := AValue;
end;

function THtmlNode.SetOnClick(AValue: TNotifyEvent): THtmlNode;
begin
  Result := Self;
  FOnClick := AValue;
end;

function THtmlNode.AppendTo(AParentNode: THtmlNode): THtmlNode;
begin
  Result := Self;
  AParentNode.AddNode(Self);
end;


function THtmlNode.SetTagStr(AValue: String): THtmlNode;
begin
  TagStr := AValue;
  Result := Self;
end;

function THtmlNode.Clear: THtmlNode;
  procedure ClearChildrens(ForNode: THtmlNode);
  var
    N: THtmlNode;
  begin
    while Assigned(ForNode) do begin
      N := ForNode;
      if ForNode.ChildCount > 0 then begin
        ClearChildrens(ForNode.FFirstChild);
        ForNode.FFirstChild := Nil;
      end;
      ForNode := ForNode.GetNext(ForNode, False);
      N.Free;
    end;
  end;
begin
  Result := Self;
  ClearChildrens(FirstChild);
  Self.FFirstChild := Nil;
  Self.FNextSibling := Nil;
  Self.FChildCount := 0;
  Self.FLastNode := Nil;
  Self.FFirstNode := Nil;
end;

function THtmlNode.AddNode(ANode: THtmlNode): THtmlNode;
  procedure SetMyParent(ForNode: THtmlNode);
  begin
    while Assigned(ForNode) do begin
      ForNode.RootNode := Self.RootNode;
      if ForNode.ChildCount > 0 then SetMyParent(ForNode.FFirstChild);
      ForNode := ForNode.GetNext(ForNode, False);
    end;
  end;
begin
  Result := Self;
  if RootNode = Nil then
    Raise Exception.Create('There is no root node!');;
  if Self = ANode then
    Raise Exception.Create('Can''t add self as children!');;
  ANode.ParentNode := Self;
  SetMyParent(ANode);
  if FFirstNode = Nil then FFirstNode := ANode;
  if FFirstChild = Nil then FFirstChild := ANode;
  if FLastNode <> Nil then FLastNode.FNextSibling := ANode;
  ANode.FPrevSibling := FLastNode;
  FLastNode := ANode;
  Inc(Self.FChildCount);
  Inc(RootNode.FTotalCount);
end;

function THtmlNode.GetNext(ANode: THtmlNode; GoAboveChildren: Boolean): THtmlNode;
begin
  Result := ANode;
  if not Assigned(Result) then exit;
  if (GoAboveChildren) then begin
    if Assigned(Result.FFirstChild) then
      Result := Result.FFirstChild
    else begin
      repeat
        if Result = Nil then Break;
        if Assigned(Result.FNextSibling) then begin
          Result := Result.FNextSibling;
          Break;
        end else begin
          if Result.ParentNode <> RootNode then
            Result := Result.ParentNode
          else begin
            Result := Nil;
            Break;
          end;
        end;
      until False;
    end;
  end else begin
    Result := ANode.FNextSibling;
  end;
end;

function THtmlNode.GetElementsByClassName(AName: String): THtmlNodeArray;
var
  Node: THtmlNode;
begin
  Node := Self;
  SetLength(Result, 0);
  while Assigned(Node) do begin
     if Node.Id = AName then begin
       SetLength(Result, Length(Result) + 1);
       Result[Length(Result)] := Node;
     end;
     Node := Node.GetNext(Node, True);
  end;
end;

function THtmlNode.GetStyleValue(AName: String): String;
// TODO: add support
begin
  Result := '';
end;

procedure THtmlNode.SetHovered(AValue: Boolean);
begin
  if FHovered = AValue then Exit;
  FHovered := AValue;
end;

procedure THtmlNode.SetHoverStyle(AValue: String);
begin
  if FHoverStyle = AValue then Exit;
  FHoverStyle := AValue;
end;

(*
  Setup inline style by user. Same like in html document:   <div style="THIS PART IS AVALUE">
*)
procedure THtmlNode.SetInlineStyle(AValue: String);
var
  I: ICSSControl;
begin
  if FInlineStyle = AValue then Exit;
  FInlineStyle := AValue;
  FCompStyle.Reset;
  if Element = 'span' then FCompStyle.Display := cdtInline; // set default display-inline for span element
  FCompStyle.Parse(FInlineStyle);
  if (Self = RootNode) and (RootNode.ParentControl <> Nil) and (RootNode.ParentControl is ICSSControl) then begin
    RootNode.ParentControl.GetInterface(HTMLInterface, I);
    I.Changed;
  end;

{  if RootNode.FParentControl <> Nil then begin
    RootNode.FParentControl.InvalidatePreferredSize;
    RootNode.FParentControl.Invalidate;
  end;}
end;

initialization
begin
  InitCSSColors;
end;

finalization
begin
  CSSColorList.Free;
end;

end.
