unit test_html;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpcunit, testregistry, cssbase, csshtml, csstailwind;

type

  { TTestHtml }

  TTestHtml = class(TTestCase)
  private
    FRoot: THtmlNode;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestElementsAndAttributes;
    procedure TestTextOnlyElement;
    procedure TestMixedContent;
    procedure TestEntities;
    procedure TestWhitespaceBetweenInlineElements;
    procedure TestVoidAndSelfClosing;
    procedure TestCommentsAndDoctype;
    procedure TestUnclosedAndWrongClosing;
    procedure TestInlineStyleAndCustomAttributes;
    procedure TestStyleElement;
    procedure TestElementDefaults;
    procedure TestImage;
    procedure TestTailwindExample;
    procedure TestSvgIcon;
  end;

implementation

procedure TTestHtml.SetUp;
begin
  FRoot := THtmlNode.Create;
end;

procedure TTestHtml.TearDown;
begin
  FRoot.Free;
end;

procedure TTestHtml.TestElementsAndAttributes;
var
  D: THtmlNode;
begin
  FRoot.AppendHTML('<div id="a" class="x y"><span class=''z''>t</span><p>p</p></div>');
  AssertEquals(1, FRoot.ChildCount);
  D := FRoot.FirstChild;
  AssertEquals('div', D.Element);
  AssertEquals('a', D.Id);
  AssertEquals('x y', D.ClassList.Name);
  AssertEquals(2, D.ChildCount);
  AssertEquals('span', D.FirstChild.Element);
  AssertEquals('z', D.FirstChild.ClassList.Name);
  AssertEquals('p', D.GetNext(D.FirstChild).Element);
  AssertTrue(FRoot.GetElementById('a') = D);
end;

procedure TTestHtml.TestTextOnlyElement;
begin
  FRoot.AppendHTML('<span>  Hello   world  </span>');
  AssertEquals('Hello world', FRoot.FirstChild.Text);
  AssertEquals(0, FRoot.FirstChild.ChildCount);
end;

procedure TTestHtml.TestMixedContent;
var
  P: THtmlNode;
begin
  FRoot.AppendHTML('<p>Hello <b>big</b> world</p>');
  P := FRoot.FirstChild;
  AssertEquals(3, P.ChildCount);
  AssertEquals('#text', P.FirstChild.Element);
  AssertEquals('Hello ', P.FirstChild.Text);
  AssertEquals('b', P.GetNext(P.FirstChild).Element);
  AssertEquals('big', P.GetNext(P.FirstChild).Text);
  AssertEquals(' world', P.GetNext(P.GetNext(P.FirstChild)).Text);
end;

procedure TTestHtml.TestWhitespaceBetweenInlineElements;
var
  D: THtmlNode;
begin
  FRoot.AppendHTML('<div><b>a</b> <i>b</i> </div><div style="display: flex"><b>a</b> <i>b</i></div>');
  D := FRoot.FirstChild;
  AssertEquals('space kept in inline content', 3, D.ChildCount);
  AssertEquals(' ', D.GetNext(D.FirstChild).Text);
  D := FRoot.GetNext(D);
  AssertEquals('space ignored in flex', 2, D.ChildCount);
end;

procedure TTestHtml.TestEntities;
begin
  AssertEquals('a & b < c', CSSDecodeEntities('a &amp; b &lt; c'));
  AssertEquals(#$C2#$B7, CSSDecodeEntities('&middot;'));
  AssertEquals(#$C2#$B7, CSSDecodeEntities('&#183;'));
  AssertEquals(#$C2#$B7, CSSDecodeEntities('&#xB7;'));
  AssertEquals('&unknown; &', CSSDecodeEntities('&unknown; &'));
  FRoot.AppendHTML('<span title="a &amp; b">&copy; 2025</span>');
  AssertEquals(#$C2#$A9' 2025', FRoot.FirstChild.Text);
  AssertEquals('a & b', FRoot.FirstChild.Attributes['title']);
end;

procedure TTestHtml.TestVoidAndSelfClosing;
var
  D: THtmlNode;
begin
  FRoot.AppendHTML('<div><img src="a.png"><br><span/>x<hr /></div>');
  D := FRoot.FirstChild;
  AssertEquals(5, D.ChildCount);
  AssertEquals('img', D.FirstChild.Element);
  AssertEquals('a.png', D.FirstChild.Attributes['src']);
  AssertEquals(0, D.FirstChild.ChildCount);
end;

procedure TTestHtml.TestCommentsAndDoctype;
begin
  FRoot.AppendHTML('<!DOCTYPE html><!-- comment <div> --><div>a</div>');
  AssertEquals(1, FRoot.ChildCount);
  AssertEquals('a', FRoot.FirstChild.Text);
end;

procedure TTestHtml.TestUnclosedAndWrongClosing;
begin
  FRoot.AppendHTML('<div><span>a</div><p>b</em></p>');
  AssertEquals(2, FRoot.ChildCount);
  AssertEquals('a', FRoot.FirstChild.FirstChild.Text);
  AssertEquals('b', FRoot.GetNext(FRoot.FirstChild).Text);
end;

procedure TTestHtml.TestInlineStyleAndCustomAttributes;
begin
  FRoot.AppendHTML('<div style="width: 10px" data-value="42"></div>');
  AssertEquals(10, FRoot.FirstChild.CompStyle.Width.Value, 0.001);
  AssertEquals('42', FRoot.FirstChild.Attributes['data-value']);
end;

procedure TTestHtml.TestStyleElement;
var
  Sheet: TCSSStyleSheet;
begin
  Sheet := TCSSStyleSheet.Create(nil);
  try
    FRoot.StyleSheet := Sheet;
    FRoot.AppendHTML('<style>.big { width: 50px }</style><div class="big"></div>');
    AssertEquals(1, FRoot.ChildCount);
    FRoot.ApplyStyles;
    AssertEquals(50, FRoot.FirstChild.CompStyle.Width.Value, 0.001);
    FRoot.StyleSheet := nil;
  finally
    Sheet.Free;
  end;
end;

procedure TTestHtml.TestElementDefaults;
var
  P: THtmlNode;
  function Child(const AElement: String): THtmlNode;
  begin
    Result := P.FirstChild;
    while Assigned(Result) and (Result.Element <> AElement) do Result := P.GetNext(Result);
  end;
begin
  FRoot.AppendHTML('<div>a <b>b</b> <i>i</i></div><span>s</span>');
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, 300, -1);
  P := FRoot.FirstChild;
  AssertTrue('div is block', P.CompStyle.Display = cdtBlock);
  AssertTrue('span is inline', FRoot.GetNext(P).CompStyle.Display = cdtInline);
  AssertTrue('b is bold', Child('b').CompStyle.Font.Weight.FontType = cfwBold);
  AssertTrue('i is italic', Child('i').CompStyle.Font.Style = cfsItalic);
end;

procedure TTestHtml.TestImage;
var
  Bmp: TBitmap;
  Img: THtmlNode;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(40, 20);
    CSSRegisterImage('img40x20', Bmp);
  finally
    Bmp.Free;
  end;
  FRoot.AppendHTML('<img src="img40x20"><img src="img40x20" style="width: 80px">');
  FRoot.ApplyStyles;
  FRoot.LayoutTo(0, 0, 300, -1);
  Img := FRoot.FirstChild;
  AssertEquals('intrinsic width', 40, Img.CompSize.ContentRect.Width);
  AssertEquals('intrinsic height', 20, Img.CompSize.ContentRect.Height);
  AssertEquals('url("img40x20")', Img.CompStyle.Background.Image);
  Img := FRoot.GetNext(Img);
  AssertEquals('aspect ratio', 40, Img.CompSize.ContentRect.Height);
end;

procedure TTestHtml.TestTailwindExample;
var
  Card, Title: THtmlNode;
begin
  CSSTailwindEnable;
  try
    FRoot.AppendHTML(
      '<div class="flex flex-col items-center p-7 rounded-2xl">' +
      '  <div>' +
      '    <img class="size-48 shadow-xl rounded-md" alt="" src="/img/cover.png" />' +
      '  </div>' +
      '  <div class="flex">' +
      '    <span id="title" class="text-2xl font-medium">Class Warfare</span>' +
      '    <span class="font-medium text-sky-500">The Anti-Patterns</span>' +
      '    <span class="flex gap-2 font-medium text-">' +
      '      <span>No. 4</span>' +
      '      <span>&middot;</span>' +
      '      <span>2025</span>' +
      '    </span>' +
      '  </div>' +
      '</div>');
    FRoot.ApplyStyles;
    FRoot.LayoutTo(0, 0, 600, -1);
    Card := FRoot.FirstChild;
    AssertTrue(Card.CompStyle.Display = cdtFlex);
    AssertEquals('img size', 192, Card.FirstChild.FirstChild.CompSize.ContentRect.Width);
    Title := FRoot.GetElementById('title');
    AssertEquals('Class Warfare', Title.Text);
    AssertEquals(24, Title.CompSize.FontSize, 0.01);
  finally
    CSSTailwindDisable;
  end;
end;

procedure TTestHtml.TestSvgIcon;
var
  Icon: THtmlNode;
  Bmp: TBitmap;
  C: TColor;
begin
  CSSTailwindEnable;
  Bmp := TBitmap.Create;
  try
    // svg copied from lucide.dev: stroked shapes, color is text color, size from classes
    FRoot.AppendHTML('<div class="flex"><svg class="size-12 text-red-600" viewBox="0 0 24 24" stroke-width="2">' +
      '<path d="M2 6h20" /><circle cx="12" cy="16" r="4"/></svg></div>');
    FRoot.ApplyStyles;
    FRoot.LayoutTo(0, 0, 100, 100);
    Icon := FRoot.FirstChild.FirstChild;
    AssertEquals('svg element', 'svg', Icon.Element);
    AssertTrue('shapes are kept as markup', Pos('<circle', Icon.Attributes['data-svg']) > 0);
    AssertTrue('no child nodes', Icon.FirstChild = nil);
    AssertEquals('size from class', 48, Icon.CompSize.ContentRect.Width);
    Bmp.SetSize(48, 48);
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.FillRect(0, 0, 48, 48);
    FRoot.PaintTo(Bmp.Canvas);
    C := Bmp.Canvas.Pixels[24, 12];              // line y=6 -> 12 px (scale 2)
    AssertTrue('line is painted with text color', (Red(C) > 180) and (Green(C) < 80));
    C := Bmp.Canvas.Pixels[24, 32];              // center of circle
    AssertEquals('inside circle is empty', clWhite, C);
    C := Bmp.Canvas.Pixels[24, 40];              // bottom of circle: y = 16 + 4 = 20 -> 40 px
    AssertTrue('circle is painted', (Red(C) > 180) and (Green(C) < 80));
  finally
    Bmp.Free;
    CSSTailwindDisable;
  end;
end;

initialization
  RegisterTest(TTestHtml);
end.
