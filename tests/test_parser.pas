unit test_parser;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpcunit, testregistry, cssbase;

type

  { TTestParser }

  TTestParser = class(TTestCase)
  private
    FItem: TCSSItem;
    procedure CheckColor(const ACSS: String; R, G, B: Byte);
    procedure CheckLength(const AExpected: TCSSLengthType; AValue: Single; const ALength: TCSSLength);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestHexColors;
    procedure TestRgbColors;
    procedure TestNamedColors;
    procedure TestSpecialColors;
    procedure TestInvalidColorDoesNotRaise;
    procedure TestLengths;
    procedure TestDecimalLengthWithCommaLocale;
    procedure TestMarginShorthand;
    procedure TestBorderShorthand;
    procedure TestBorderLonghands;
    procedure TestBorderRadius;
    procedure TestFlexProperties;
    procedure TestFlexShorthand;
    procedure TestGap;
    procedure TestFontProperties;
    procedure TestFontShorthand;
    procedure TestUnknownValuesUseDefaults;
    procedure TestImportantIsIgnored;
    procedure TestResetRestoresDefaults;
    procedure TestStyleSheetKeepsSelectorWithSpaces;
    procedure TestColorAlpha;
    procedure TestBackgroundProperties;
    procedure TestCustomProperties;
  end;

implementation

procedure TTestParser.CheckColor(const ACSS: String; R, G, B: Byte);
begin
  FItem.Reset;
  FItem.Parse('color:' + ACSS);
  AssertTrue(ACSS + ' type', FItem.Color.ColorType = cctNormal);
  AssertEquals(ACSS, RGBToColor(R, G, B), FItem.Color.Value);
end;

procedure TTestParser.CheckLength(const AExpected: TCSSLengthType; AValue: Single; const ALength: TCSSLength);
begin
  AssertTrue('length type', AExpected = ALength.LengthType);
  AssertEquals('length value', AValue, ALength.Value, 0.0001);
end;

procedure TTestParser.SetUp;
begin
  FItem := TCSSItem.Create;
end;

procedure TTestParser.TearDown;
begin
  FItem.Free;
end;

procedure TTestParser.TestHexColors;
begin
  CheckColor('#ff8000', 255, 128, 0);
  CheckColor('#FF8000', 255, 128, 0);
  CheckColor('#abc', $aa, $bb, $cc);
  CheckColor('#abcf', $aa, $bb, $cc);
  CheckColor('#11223344', $11, $22, $33);
end;

procedure TTestParser.TestRgbColors;
begin
  CheckColor('rgb(1, 2, 3)', 1, 2, 3);
  CheckColor('rgb(1 2 3)', 1, 2, 3);
  CheckColor('rgba(10,20,30,0.5)', 10, 20, 30);
  CheckColor('rgb(100%, 0%, 50%)', 255, 0, 128);
end;

procedure TTestParser.TestNamedColors;
begin
  CheckColor('red', 255, 0, 0);
  CheckColor('RebeccaPurple', $66, $33, $99);
  CheckColor('aliceblue', $f0, $f8, $ff);
end;

procedure TTestParser.TestSpecialColors;
begin
  FItem.Parse('background-color: transparent');
  AssertTrue(FItem.Background.Color.ColorType = cctTransparent);
  FItem.Parse('background-color: rgba(0,0,0,0)');
  AssertTrue(FItem.Background.Color.ColorType = cctTransparent);
end;

procedure TTestParser.TestInvalidColorDoesNotRaise;
begin
  FItem.Parse('color:#zzz;background-color:#12;border-color: rgb(a,b,c)');
  AssertTrue(FItem.Color.ColorType = cctUndefined);
  AssertTrue(FItem.Background.Color.ColorType = cctUndefined);
end;

procedure TTestParser.TestLengths;
begin
  FItem.Parse('width:10px;height:1.5px;left:12pt;top:2em;margin-left:1.25rem;margin-top:50%;margin-right:auto;margin-bottom:0;padding-left:-3px;padding-top:150%');
  CheckLength(cltPx, 10, FItem.Width);
  CheckLength(cltPx, 1.5, FItem.Height);
  CheckLength(cltPt, 12, FItem.Left);
  CheckLength(cltEm, 2, FItem.Top);
  CheckLength(cltRem, 1.25, FItem.Margin[csLeft]);
  CheckLength(cltPercentage, 50, FItem.Margin[csTop]);
  AssertTrue(FItem.Margin[csRight].LengthType = cltAuto);
  CheckLength(cltPx, 0, FItem.Margin[csBottom]);
  CheckLength(cltPx, -3, FItem.Padding[csLeft]);
  CheckLength(cltPercentage, 150, FItem.Padding[csTop]);
end;

procedure TTestParser.TestDecimalLengthWithCommaLocale;
var
  OldSep: Char;
begin
  OldSep := DefaultFormatSettings.DecimalSeparator;
  DefaultFormatSettings.DecimalSeparator := ',';
  try
    FItem.Parse('flex-grow:0.5;width:2.5px');
    AssertEquals(0.5, FItem.FlexGrow, 0.0001);
    CheckLength(cltPx, 2.5, FItem.Width);
  finally
    DefaultFormatSettings.DecimalSeparator := OldSep;
  end;
end;

procedure TTestParser.TestMarginShorthand;
begin
  FItem.Parse('margin: 1px 2px 3px');
  CheckLength(cltPx, 1, FItem.Margin[csTop]);
  CheckLength(cltPx, 2, FItem.Margin[csRight]);
  CheckLength(cltPx, 3, FItem.Margin[csBottom]);
  CheckLength(cltPx, 2, FItem.Margin[csLeft]);
  FItem.Parse('padding: 1px 2px 3px 4px');
  CheckLength(cltPx, 4, FItem.Padding[csLeft]);
  FItem.Parse('margin: 0 auto');
  AssertTrue(FItem.Margin[csLeft].LengthType = cltAuto);
  AssertTrue(FItem.Margin[csRight].LengthType = cltAuto);
  CheckLength(cltPx, 0, FItem.Margin[csTop]);
end;

procedure TTestParser.TestBorderShorthand;
begin
  FItem.Parse('border: 1px solid');
  CheckLength(cltPx, 1, FItem.Border[csTop].Width);
  AssertTrue(FItem.Border[csTop].Style = cbsSolid);
  AssertTrue(FItem.Border[csTop].Color.ColorType = cctCurrentColor);

  FItem.Parse('border-left: dotted red 2px');
  AssertTrue(FItem.Border[csLeft].Style = cbsDotted);
  CheckLength(cltPx, 2, FItem.Border[csLeft].Width);
  AssertEquals(clRed, FItem.Border[csLeft].Color.Value);

  FItem.Parse('border: none');
  AssertTrue(FItem.Border[csRight].Style = cbsNone);

  FItem.Parse('border: thick dashed');
  CheckLength(cltPx, 5, FItem.Border[csBottom].Width);
end;

procedure TTestParser.TestBorderLonghands;
begin
  FItem.Parse('border-style: solid; border-width: 1px 2px; border-color: red blue; border-top-width: 7px');
  AssertTrue(FItem.Border[csLeft].Style = cbsSolid);
  CheckLength(cltPx, 7, FItem.Border[csTop].Width);
  CheckLength(cltPx, 2, FItem.Border[csRight].Width);
  CheckLength(cltPx, 1, FItem.Border[csBottom].Width);
  AssertEquals(clRed, FItem.Border[csBottom].Color.Value);
  AssertEquals(clBlue, FItem.Border[csLeft].Color.Value);
end;

procedure TTestParser.TestBorderRadius;
begin
  FItem.Parse('border-radius: 1px 2px 3px');
  CheckLength(cltPx, 1, FItem.RadiusTopLeft.Width);
  CheckLength(cltPx, 2, FItem.RadiusTopRight.Width);
  CheckLength(cltPx, 3, FItem.RadiusBottomRight.Width);
  CheckLength(cltPx, 2, FItem.RadiusBottomLeft.Width);
  FItem.Parse('border-radius: 50%');
  CheckLength(cltPercentage, 50, FItem.RadiusBottomLeft.Height);
end;

procedure TTestParser.TestFlexProperties;
begin
  FItem.Parse('flex-direction: column; flex-wrap: wrap; justify-content: space-between; align-items: center; align-self: flex-end; order: 2; flex-shrink: 0; flex-basis: 25%');
  AssertTrue(FItem.FlexDirection = cfdColumn);
  AssertTrue(FItem.FlexWrap = cfwWrap);
  AssertTrue(FItem.JustifyContent = cjcSpaceBetween);
  AssertTrue(FItem.AlignItems = caiCenter);
  AssertTrue(FItem.AlignSelf = caiFlexEnd);
  AssertEquals(2, FItem.Order);
  AssertEquals(0, FItem.FlexShrink, 0.001);
  CheckLength(cltPercentage, 25, FItem.FlexBasis);
end;

procedure TTestParser.TestFlexShorthand;
begin
  FItem.Parse('flex: 1');
  AssertEquals(1, FItem.FlexGrow, 0.001);
  AssertEquals(1, FItem.FlexShrink, 0.001);
  CheckLength(cltPx, 0, FItem.FlexBasis);
  FItem.Parse('flex: none');
  AssertEquals(0, FItem.FlexGrow, 0.001);
  AssertEquals(0, FItem.FlexShrink, 0.001);
  FItem.Parse('flex: 2 0 10px');
  AssertEquals(2, FItem.FlexGrow, 0.001);
  AssertEquals(0, FItem.FlexShrink, 0.001);
  CheckLength(cltPx, 10, FItem.FlexBasis);
end;

procedure TTestParser.TestGap;
begin
  FItem.Parse('gap: 4px 8px');
  CheckLength(cltPx, 4, FItem.RowGap);
  CheckLength(cltPx, 8, FItem.ColumnGap);
  FItem.Parse('gap: 1rem');
  CheckLength(cltRem, 1, FItem.ColumnGap);
end;

procedure TTestParser.TestFontProperties;
begin
  FItem.Parse('font-size: 14px; font-family: "Helvetica Neue", Arial, sans-serif; font-style: italic; font-weight: 700');
  CheckLength(cltPx, 14, FItem.Font.Size);
  AssertEquals('"Helvetica Neue", Arial, sans-serif', FItem.Font.Family);
  AssertTrue(FItem.Font.Style = cfsItalic);
  AssertTrue(FItem.Font.Weight.FontType = cfwBold);
  AssertTrue(cipFontSize in FItem.Specified);
  FItem.Parse('font-weight: normal');
  AssertTrue(FItem.Font.Weight.FontType = cfwNormal);
  FItem.Parse('font-weight: 300');
  AssertTrue(FItem.Font.Weight.FontType = cfwNormal);
end;

procedure TTestParser.TestFontShorthand;
begin
  FItem.Parse('font: italic bold 12px/1.5 Arial, sans-serif');
  CheckLength(cltPx, 12, FItem.Font.Size);
  AssertTrue(FItem.Font.Style = cfsItalic);
  AssertTrue(FItem.Font.Weight.FontType = cfwBold);
  AssertEquals('Arial, sans-serif', FItem.Font.Family);
end;

procedure TTestParser.TestUnknownValuesUseDefaults;
begin
  FItem.Parse('display: grid; text-align: start; align-items: space-around; overflow: clip');
  AssertTrue(FItem.Display = cdtBlock);
  AssertTrue(FItem.TextAlign = ctaLeft);
  AssertTrue(FItem.AlignItems = caiStretch);
  AssertTrue(FItem.Overflow = cotVisible);
end;

procedure TTestParser.TestImportantIsIgnored;
begin
  FItem.Parse('width: 10px !important');
  CheckLength(cltPx, 10, FItem.Width);
end;

procedure TTestParser.TestResetRestoresDefaults;
begin
  FItem.Parse('border-radius: 5px; position: absolute; flex-grow: 1; overflow: hidden; text-align: center; float: left; top: 1px');
  FItem.Reset;
  AssertTrue(FItem.RadiusTopLeft.Width.LengthType = cltUndefined);
  AssertTrue(FItem.Position = cpStatic);
  AssertEquals(0, FItem.FlexGrow, 0.001);
  AssertTrue(FItem.Overflow = cotVisible);
  AssertTrue(FItem.TextAlign = ctaUndefined);
  AssertTrue(FItem.Float = cftNone);
  AssertTrue(FItem.Top.LengthType = cltUndefined);
  AssertTrue(FItem.Specified = []);
end;

procedure TTestParser.TestStyleSheetKeepsSelectorWithSpaces;
var
  Sheet: TCSSStyleSheet;
begin
  Sheet := TCSSStyleSheet.Create(nil);
  try
    Sheet.Style := '.a .b, .c > .d { color: red } .e{color:blue} .e{width:1px}';
    AssertEquals(4, Sheet.Count);
    AssertNotNull(Sheet.Selector['.a .b']);
    AssertNotNull(Sheet.Selector['.c > .d']);
    AssertEquals('width:1px', Sheet.Selector['.e'].Attributes);
  finally
    Sheet.Free;
  end;
end;

procedure TTestParser.TestColorAlpha;
begin
  FItem.Parse('color: rgba(1,2,3,0.5)');
  AssertEquals(128, FItem.Color.Alpha);
  FItem.Parse('color: #11223380');
  AssertEquals($80, FItem.Color.Alpha);
  FItem.Parse('color: red');
  AssertEquals(255, FItem.Color.Alpha);
end;

procedure TTestParser.TestBackgroundProperties;
begin
  FItem.Parse('background: url(a.png) no-repeat center / cover #fff');
  AssertEquals('url(a.png)', FItem.Background.Image);
  AssertEquals('no-repeat', FItem.Background.RepeatMode);
  AssertEquals('center', FItem.Background.Position);
  AssertEquals('cover', FItem.Background.Size);
  AssertEquals(clWhite, FItem.Background.Color.Value);
  FItem.Parse('background: red');
  AssertEquals('none', FItem.Background.Image);
  FItem.Parse('background-image: linear-gradient(to right, red, blue); background-size: 10px 20px');
  AssertEquals('linear-gradient(to right, red, blue)', FItem.Background.Image);
  AssertEquals('10px 20px', FItem.Background.Size);
end;

procedure TTestParser.TestCustomProperties;
begin
  FItem.Parse('--tw-gradient-from: #fff; --x: rgba(1, 2, 3, 0)');
  AssertEquals('#fff', FItem.CustomProps.Values['--tw-gradient-from']);
  AssertEquals('rgba(1, 2, 3, 0)', FItem.CustomProps.Values['--x']);
  FItem.Reset;
  AssertEquals(0, FItem.CustomProps.Count);
end;

initialization
  RegisterTest(TTestParser);
end.
