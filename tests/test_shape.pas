unit test_shape;

(*
  TCSSShape: HTML, CSS and BodyClass properties (Object Inspector) and streaming (.lfm)
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpcunit, testregistry, cssbase, CSSCtrls, csstailwind, csscomponents;

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

initialization
  RegisterTest(TTestShape);
end.
