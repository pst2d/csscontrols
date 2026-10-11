unit test_shape;

(*
  TCSSShape: HTML, CSS and BodyClass properties (Object Inspector) and streaming (.lfm)
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Forms, fpcunit, testregistry, cssbase, CSSCtrls, csstailwind, csscomponents;

type

  { TTestShape }

  TTestShape = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestHTMLProperty;
    procedure TestStreaming;
    procedure TestTabsIndicator;
    procedure TestTabsResize;
  end;

implementation

procedure TTestShape.SetUp;
begin
  CSSTailwindEnable;
end;

procedure TTestShape.TearDown;
begin
  CSSTailwindDisable;
end;

procedure TTestShape.TestHTMLProperty;
var
  S: TCSSShape;
  N: THtmlNode;
begin
  S := TCSSShape.Create(nil);
  try
    S.CSS.Text := '.title { font-weight: bold }';
    S.BodyClass := 'p-4';
    S.HTML.Text := '<div id="t" class="title text-red-500">Hello</div>';
    N := S.Body.GetElementById('t');
    AssertNotNull('node from markup', N);
    AssertEquals('text', 'Hello', N.Text);
    AssertTrue('stylesheet rule', fsBold in N.CompStyle.Font.Weight.Value);
    AssertEquals('body class', 16, S.Body.CompSize.Padding.Left);
  finally
    S.Free;
  end;
end;

procedure TTestShape.TestStreaming;
var
  S, S2: TCSSShape;
  Stream: TMemoryStream;
begin
  S := TCSSShape.Create(nil);
  S2 := TCSSShape.Create(nil);
  Stream := TMemoryStream.Create;
  try
    S.HTML.Text := '<span id="x" class="font-bold">Saved</span>';
    S.BodyClass := 'flex';
    Stream.WriteComponent(S);
    Stream.Position := 0;
    Stream.ReadComponent(S2);
    AssertEquals('HTML is stored', S.HTML.Text, S2.HTML.Text);
    AssertEquals('BodyClass is stored', 'flex', S2.BodyClass);
    AssertNotNull('content is built after loading', S2.Body.GetElementById('x'));
  finally
    Stream.Free;
    S2.Free;
    S.Free;
  end;
end;

procedure TTestShape.TestTabsIndicator;
var
  T: TCSSTabs;
  Bmp: TBitmap;
begin
  T := TCSSTabs.Create(nil);
  Bmp := TBitmap.Create;
  try
    T.SetBounds(0, 0, 200, 36);
    T.Tabs.Text := 'One'#10'Two'#10'Three'#10'Four'#10'Five'#10'Six'#10'Seven'#10'Eight';
    Bmp.SetSize(200, 36);
    T.Body.PaintTo(Bmp.Canvas);          // transitions start only for painted nodes
    AssertFalse('no animation', T.Body.Animating);
    T.TabIndex := 7;
    AssertTrue('indicator moves with transition', T.Body.Animating);
    AssertTrue('last tab is scrolled into view', T.Body.FirstChild.ScrollX > 0);
  finally
    Bmp.Free;
    T.Free;
  end;
end;

procedure TTestShape.TestTabsResize;
var
  F: TForm;
  T: TCSSTabs;
  Tab: THtmlNode;
  W: Integer;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  CSSAnimationsEnabled := False;
  F := TForm.CreateNew(nil);
  try
    F.SetBounds(0, 0, 700, 200);
    T := TCSSTabs.Create(F);
    T.Parent := F;                       // created 240 px wide, then stretched (align, anchors, form scaling)
    T.SetBounds(0, 0, 660, 36);
    Tab := T.Body.FirstChild.FirstChild.ParentNode.GetNext(T.Body.FirstChild.FirstChild);
    W := Tab.CompSize.ContentRect.Width;
    AssertTrue('tab is wider after resize', W > 150);
    AssertTrue('indicator width follows tab: ' + T.Body.FirstChild.FirstChild.InlineStyle,
      Pos(Format('width: %.2fpx', [W / T.Body.PixelRatio], FS), T.Body.FirstChild.FirstChild.InlineStyle) > 0);
  finally
    F.Free;
    CSSAnimationsEnabled := True;
  end;
end;

initialization
  RegisterTest(TTestShape);
end.
