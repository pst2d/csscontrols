unit CSSCtrls;

{$ifdef fpc}
  {$mode delphi}{$H+}
{$endif}

interface
uses
  Classes, SysUtils,  Types, Math,
  strutils,
  {$ifdef fpc}
  Controls,  Graphics, Forms, ExtCtrls, StdCtrls,
  LMessages,LCLIntf, LazUTF8,
  FPimage, LCLType, LCLProc, IntfGraphics, GraphType, EasyLazFreeType, LazFreeTypeIntfDrawer,      // font rendering
  {$endif}
  cssbase, csshtml, csstailwind;

type

  TCSSNodeEvent = procedure(Sender: TObject; ANode: THtmlNode) of object;

  { TCSSShape }

  TCSSShape = Class(TGraphicControl, ICSSControl)
  private
    FCachedWidth,
    FCachedHeight: Integer;
    FIsChanged: Boolean;
    FLayoutValid: Boolean;          // layout of body is for current size (CalculatePreferredSize can change it)
    FMouseDownNode: THtmlNode;
    FOnPaint: TNotifyEvent;
    FBodyNode: THtmlNode;
    FScaleByDPI: Boolean;
    FDragNode: THtmlNode;           // node with dragged scrollbar thumb
    FDragAxis, FDragStart, FDragScroll: Integer;
    FAnimTimer: TTimer;             // runs only while some nodes are animated (or smooth scroll)
    FSmoothNode: THtmlNode;         // smooth scroll (mouse wheel): node, start and target position
    FSmoothFrom, FSmoothTo: TPoint;
    FSmoothStart: QWord;
    FLastWheel: QWord;
    FWheelControls: TList;          // LCL controls in nodes, mouse wheel over them scrolls content
    FHTML, FCSS: TStrings;          // markup and stylesheet set in Object Inspector (design time)
    FBodyClass: String;
    FSheet: TCSSStyleSheet;
    FInspect: Boolean;              // debug overlay of node under mouse (like browser inspector)
    FHoverEnabled: Boolean;
    FBuffered: Boolean;
    FBuffer: TBitmap;               // painted content (shape with opaque background on not scaled canvas)
    FBufferDirty: TRect;            // area of buffer which is painted again
    FBufferValid: Boolean;          // buffer contains whole shape (False after shape was painted directly)
    FInspectNode: THtmlNode;
    FOnInspect: TCSSNodeEvent;
    function UseBuffer: Boolean;
    procedure PaintToBuffer(const ARect: TRect);
    procedure SetInspect(AValue: Boolean);
    procedure SetHTML(AValue: TStrings);
    procedure SetCSS(AValue: TStrings);
    procedure SetBodyClass(const AValue: String);
    procedure MarkupChanged(Sender: TObject);
    procedure AnimTimer(Sender: TObject);
    procedure StartAnimations;
    procedure InvalidateArea(const ARect: TRect);
    function FocusControlOf(ANode: THtmlNode): Boolean;
    function GetBodyNode: THtmlNode;
    function ScrollAt(const APos: TPoint; DX, DY: Integer; ASmooth: Boolean = False): Boolean;
    function ScrollNodeAt(const APos: TPoint; var DX, DY: Integer): THtmlNode;
    function TickSmoothScroll: Boolean;
    function WheelScroll(const APos: TPoint; WheelDelta: Integer; AHorz: Boolean): Boolean;
    procedure ControlMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure HookControlWheels;
    procedure ScrollChanged(ANode: THtmlNode);
    procedure ActiveControlChanged(Sender: TObject; LastControl: TControl);
    function GetStyle: String;
    procedure SetScaleByDPI(AValue: Boolean);
    procedure SetStyle(AValue: String);
    procedure Relayout(AWidth, AHeight: Integer);
    procedure UpdatePixelRatio;
    procedure UpdateViewport(AWidth: Integer);
    procedure SetActiveNodes(X, Y: Integer; AActive: Boolean);
    procedure RestyleNodes(ANodes: TList);
  protected
    procedure CalculatePreferredSize(var PreferredWidth,
      PreferredHeight: Integer; WithThemeSpace: Boolean); override;
    procedure Paint; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure RebuildMarkup; virtual;
    procedure PaintInspector(ACanvas: TCanvas; ANode: THtmlNode);
    procedure SetParent(NewParent: TWinControl); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer
      ); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
      override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseEnter; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    function DoMouseWheelHorz(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Changed;
    procedure ChangeBounds(ALeft, ATop, AWidth, AHeight: integer;
      KeepBase: boolean); override;
    function NodeMarginToScreen(ANode: THtmlNode): TRect;
    function NodeMarginToClient(ANode: THtmlNode): TRect;
    property InspectNode: THtmlNode read FInspectNode;
    property HoverEnabled: Boolean read FHoverEnabled write FHoverEnabled;   // False: no :hover (eg. while something is dragged)
    // painted content is kept in a bitmap, repaint requested by system (control moved above it, window uncovered)
    // only copies it; used for shape with opaque body background on not scaled canvas (Windows, Linux)
    property Buffered: Boolean read FBuffered write FBuffered;
    procedure Invalidate; override;

  published
    property Align;
    property AutoSize;
    property Anchors;
    property Body: THtmlNode read GetBodyNode;
    property BodyClass: String read FBodyClass write SetBodyClass;   // utility classes of body node
    property CSS: TStrings read FCSS write SetCSS;                    // stylesheet rules
    property HTML: TStrings read FHTML write SetHTML;                 // markup of content (csshtml), nodes are found by GetElementById
    property BorderSpacing;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property ParentShowHint;
    property ScaleByDPI: Boolean read FScaleByDPI write SetScaleByDPI default True;  // scale CSS px by screen DPI (Windows, Linux)
    property Inspect: Boolean read FInspect write SetInspect default False;   // debug: show boxes of node under mouse
    property OnInspect: TCSSNodeEvent read FOnInspect write FOnInspect;       // node under mouse in Inspect mode was changed
    property OnChangeBounds;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;
    property OnResize;
    property OnStartDock;
    property OnStartDrag;
    property ShowHint;
    property Style: String read GetStyle write SetStyle;
    property Visible;
  end;

  { TFaIcon }

 TFaIcon = class
  private
		FCachedBitmap: TBitmap;
    FCachedIcon: String;
    FCachedColor: TColor;
	public
		constructor Create;
		destructor Destroy; override;
		function Icon(AIcon: String; ASize: Integer; AColor: TColor): TBitmap;
    property Bitmap: TBitmap read FCachedBitmap;
	end;


  { THTMLFaNode }

  THTMLFaNode = class (THtmlNode)
  private
    FA: TFaIcon;
    FIconSize: Integer;
  protected
    procedure DrawNode(ACanvas: TCanvas; AClipRect: TRect); override;
    procedure CalculateSize(out AWidth, AHeight, ABaseLine: Integer); override;
  public
    Icon: String;
    constructor Create(AInlineStyle: String = '');override;
    destructor Destroy; override;
  end;

  function HTMLFa(AInlineStyle: String; AIcon: String = ''; AId: String = ''): THTMLFaNode;
  procedure SetFontAwesomeFile(const AFileName: String);
  procedure CSSSetDarkMode(AValue: Boolean);    // dark: variant on/off, all TCSSShape controls are updated
  procedure Register;

implementation
{$R csspckg_lazarus.res}

var
  FAFont: TFreeTypeFont;
  CSSShapes: TList;           // all TCSSShape controls (dark mode is applied to them)

procedure CSSSetDarkMode(AValue: Boolean);
var
  I: Integer;
begin
  CSSDarkMode := AValue;
  if CSSShapes = nil then Exit;
  for I := 0 to CSSShapes.Count - 1 do
    with TCSSShape(CSSShapes[I]) do begin
      Body.ApplyStyles;
      Changed;
    end;
end;


function HTMLFa(AInlineStyle: String; AIcon: String; AId: String): THTMLFaNode;
begin
  Result := THTMLFaNode.Create;
  Result.InlineStyle := AInlineStyle;
  Result.Id := AId;
  Result.Element := 'span';
  Result.Icon := Copy(AIcon, 1,4);
end;

procedure Register;
begin
  CSSTailwindEnable;     // utility classes are shown in form designer (application calls CSSTailwindEnable too)
  CSSAnimationsEnabled := False;   // no animation timer in designer, changed style is shown at once
	RegisterComponents('CSS',[ TCSSShape]);
end;

{ THTMLFaNode }

procedure THTMLFaNode.DrawNode(ACanvas: TCanvas; AClipRect: TRect);
var
  X, Y: Integer;
  Scale: Single;
begin
  inherited DrawNode(ACanvas, AClipRect);
  X := CompSize.ContentRect.Left + CompSize.Border.Left + CompSize.Padding.Left;
  Y := CompSize.ContentRect.Top + CompSize.Border.Top + CompSize.Padding.Top;
  Scale := RootNode.PaintScale;
  if Scale > 1 then     // icon in device resolution (Retina)
    ACanvas.StretchDraw(Rect(X, Y, X + FIconSize, Y + FIconSize), FA.Icon(Icon, Round(FIconSize * Scale), CompStyle.Color.Value))
  else
    ACanvas.Draw(X, Y, FA.Icon(Icon, FIconSize, CompStyle.Color.Value));
end;

procedure THTMLFaNode.CalculateSize(out AWidth, AHeight, ABaseLine: Integer);
begin
  Text := ' ';
  inherited CalculateSize(AWidth, AHeight, ABaseLine);
  Text := '';
  FIconSize := AHeight;
  AWidth := FIconSize;
  ABaseLine := Round( AHeight / 5);
//  ABaseLine :=  Round(FIconSize * 0.14);  // https://stackoverflow.com/questions/32781414/what-is-the-baseline-font-height-of-fontawesome-font
end;

constructor THTMLFaNode.Create(AInlineStyle: String);
begin
  inherited Create(AInlineStyle);
  FA := TFaIcon.Create;
end;

destructor THTMLFaNode.Destroy;
begin
  FA.Free;
  inherited Destroy;
end;

{ TFaIcon }

constructor TFaIcon.Create;
begin
	FCachedBitmap := TBitmap.Create;
  FCachedIcon := '';
  FCachedColor := clNone;
end;

destructor TFaIcon.Destroy;
begin
  FCachedBitmap.Free;
  inherited Destroy;
end;

function TFaIcon.Icon(AIcon: String; ASize: Integer; AColor: TColor): TBitmap;
var
	img: TLazIntfImage;
	d: TIntfFreeTypeDrawer;
begin
	Result := FCachedBitmap;
  if Length(AIcon) >= 4 then AIcon := UTF8Encode( WideChar(Hex2Dec( Copy(AIcon, 1, 4))));
  if (AIcon = FCachedIcon) and (FCachedColor = AColor) and (ASize = FCachedBitmap.Width) then Exit;
	FCachedIcon := AIcon;
	FCachedColor := AColor;
	img := TLazIntfImage.Create(0,0, [riqfRGB, riqfAlpha]);
	d := TIntfFreeTypeDrawer.Create(img);
	try
  	img.SetSize(ASize, ASize);
		d.FillPixels(colTransparent);
    if FAFont.Name <> '' then begin
		  FAFont.SizeInPixels := ASize-2;
		  FAFont.Hinted := True;
		  FAFont.ClearType := True;
		  FAFont.Quality := grqHighQuality;
		  FAFont.SmallLinePadding := False;
  		d.DrawText(FCachedIcon, FAFont, ASize div 2, 1, TColorToFPColor(FCachedColor), [ftaTop, {ftaLeft}ftaCenter]);
    end;
    FCachedBitmap.LoadFromIntfImage(img);
	finally
		d.Free;
		img.Free;
	end;
end;

{ TCSSShape }

function TCSSShape.GetBodyNode: THtmlNode;
begin
  Result := FBodyNode;
end;

function TCSSShape.GetStyle: String;
begin
  Result := Body.InlineStyle;
end;

procedure TCSSShape.SetScaleByDPI(AValue: Boolean);
begin
  if FScaleByDPI = AValue then Exit;
  FScaleByDPI := AValue;
  Changed;
end;

procedure TCSSShape.SetStyle(AValue: String);
begin
  if Body.InlineStyle = AValue then Exit;
  Body.InlineStyle := AValue;
  Body.ApplyStyles;
  Changed;
end;

(*
  CSS px are scaled by screen DPI on Windows and Linux (macOS uses points, scaling is done by system)
*)
procedure TCSSShape.UpdatePixelRatio;
var
  Ratio: Single;
begin
  Ratio := 1;
  {$ifndef darwin}
  if FScaleByDPI and (Screen.PixelsPerInch > 96) then Ratio := Screen.PixelsPerInch / 96;
  {$endif}
  Body.PixelRatio := Ratio;
end;

(*
  Responsive utility variants (sm:, md: ...) are based on control width in CSS px
*)
procedure TCSSShape.UpdateViewport(AWidth: Integer);
  function Breakpoint(AValue: Integer): Integer;
  begin
    if AValue < 0 then Result := -1 else
    if AValue >= 1536 then Result := 5 else
    if AValue >= 1280 then Result := 4 else
    if AValue >= 1024 then Result := 3 else
    if AValue >= 768 then Result := 2 else
    if AValue >= 640 then Result := 1 else
      Result := 0;
  end;
var
  NewWidth: Integer;
begin
  if Body.PixelRatio > 0 then NewWidth := Round(AWidth / Body.PixelRatio) else NewWidth := AWidth;
  if Body.ViewportWidth = NewWidth then Exit;
  if Breakpoint(Body.ViewportWidth) <> Breakpoint(NewWidth) then begin
    Body.ViewportWidth := NewWidth;
    Body.ApplyStyles;
  end else
    Body.ViewportWidth := NewWidth;
end;

procedure TCSSShape.Relayout(AWidth, AHeight: Integer);
var
  T: Double;
begin
  if (FCachedWidth <> AWidth) or (FCachedHeight <> AHeight) or FIsChanged or not FLayoutValid then begin
    UpdatePixelRatio;
    UpdateViewport(AWidth);
    T := CSSTimeMs;
    Body.LayoutTo(0, 0, AWidth, AHeight);
    Inc(CSSStats.Layouts);
    CSSStats.LayoutMs := CSSStats.LayoutMs + CSSTimeMs - T;
    Body.AlignControlsTo(Left, Top);
    HookControlWheels;
    FLayoutValid := True;
  end;
  FCachedWidth := AWidth;
  FCachedHeight := AHeight;
  FIsChanged := False;
end;

procedure TCSSShape.Paint;
var
  R: TRect;
  T: Double;
begin
  if (csDesigning in ComponentState) and (Body.FirstChild = nil) and (Body.Text = '') and (FCSS.Count = 0) and (FBodyClass = '') then begin
    Canvas.Pen.Style := psDash;      // empty shape in form designer
    Canvas.Pen.Color := clGray;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Font.Color := clGray;
    Canvas.TextOut(4, 4, Name);
    Exit;
  end;
  if Assigned(Parent) then Body.PaintScale := Parent.GetCanvasScaleFactor;   // 2 on macOS Retina
  if not FLayoutValid then begin     // layout was changed by CalculatePreferredSize
    T := CSSTimeMs;
    Body.LayoutTo(0, 0, Width, Height);
    Inc(CSSStats.Layouts);
    CSSStats.LayoutMs := CSSStats.LayoutMs + CSSTimeMs - T;
    FLayoutValid := True;
  end;
  // only invalidated area is painted (nodes outside of it are skipped)
  R := TRect.Intersect(Canvas.ClipRect, ClientRect);
  if R.IsEmpty then R := ClientRect;
  // whole shape is painted directly when buffer doesn't exist or has other size (resize: no bitmap is allocated
  // in every step), otherwise into buffer (it stays valid for next changes and repaints requested by system)
  if UseBuffer and (not ((FBufferDirty.Width >= Width) and (FBufferDirty.Height >= Height)) or
    (Assigned(FBuffer) and (FBuffer.Width = Width) and (FBuffer.Height = Height))) then begin
    // buffer: changed area is painted into bitmap, requested area is copied from it
    if (FBuffer = nil) or not FBufferValid or (FBuffer.Width <> Width) or (FBuffer.Height <> Height) then begin
      if FBuffer = nil then begin
        FBuffer := TBitmap.Create;
        FBuffer.PixelFormat := pf24bit;       // opaque: copied by BitBlt
      end;
      if (FBuffer.Width <> Width) or (FBuffer.Height <> Height) then FBuffer.SetSize(Width, Height);
      FBufferDirty := ClientRect;
      FBufferValid := True;
    end;
    FBufferDirty := TRect.Intersect(FBufferDirty, ClientRect);
    if not FBufferDirty.IsEmpty then begin
      T := CSSTimeMs;
      PaintToBuffer(FBufferDirty);
      T := CSSTimeMs - T;
      Inc(CSSStats.Paints);
      CSSStats.PaintMs := CSSStats.PaintMs + T;
      if T > CSSStats.MaxPaintMs then CSSStats.MaxPaintMs := T;
      Inc(CSSStats.PaintPixels, Int64(FBufferDirty.Width) * FBufferDirty.Height);
      FBufferDirty := Rect(0, 0, 0, 0);
    end;
    Canvas.CopyRect(R, FBuffer.Canvas, R);
  end else begin
    FBufferValid := False;
    FBufferDirty := Rect(0, 0, 0, 0);
    if Assigned(FBuffer) and ((FBuffer.Width <> Width) or (FBuffer.Height <> Height) or not UseBuffer) then
      FreeAndNil(FBuffer);                  // size changed: memory is released (buffer is created again when needed)
    T := CSSTimeMs;
    Body.PaintTo(Self.Canvas, R);
    T := CSSTimeMs - T;
    Inc(CSSStats.Paints);
    CSSStats.PaintMs := CSSStats.PaintMs + T;
    if T > CSSStats.MaxPaintMs then CSSStats.MaxPaintMs := T;
    Inc(CSSStats.PaintPixels, Int64(R.Width) * R.Height);
  end;
  if FInspect and Assigned(FInspectNode) then PaintInspector(Canvas, FInspectNode);
  if Assigned(FOnPaint) then FOnPaint(Self);
  StartAnimations;
end;

(*
  Timer runs while some nodes are animated. Transition starts with shown values, so its first frame can look
  the same and nothing is painted: timer must be started also after styles are changed, not only in Paint.
*)
procedure TCSSShape.StartAnimations;
begin
  if not (csDesigning in ComponentState) and not FAnimTimer.Enabled and Body.Animating then begin
    FAnimTimer.Interval := 15;
    FAnimTimer.Enabled := True;
  end;
end;

(*
  Next frame of animations: only animated area is repainted (old and new position)
*)
procedure TCSSShape.AnimTimer(Sender: TObject);
var
  Before, After: TCSSRectArray;
  I: Integer;
  Smooth: Boolean;
begin
  Smooth := TickSmoothScroll;
  Before := Body.AnimationRects;
  if not Body.AnimationTick(GetTickCount64) then begin
    if not Smooth then FAnimTimer.Enabled := False;
    Exit;
  end;
  if Smooth then FAnimTimer.Interval := 15;
  if FInspect then begin
    Invalidate;
    Exit;
  end;
  // transitions are smooth (60 fps), endless built-in animations (spinner ...) use 30 fps to save CPU
  if Body.AnimatingTransitions or Smooth then FAnimTimer.Interval := 15 else FAnimTimer.Interval := 33;
  // every animated node is repainted separately (old and new position), not union of all nodes
  After := Body.AnimationRects;
  for I := 0 to High(Before) do InvalidateArea(Before[I]);
  for I := 0 to High(After) do InvalidateArea(After[I]);
end;

procedure TCSSShape.InvalidateArea(const ARect: TRect);
var
  R: TRect;
begin
  if ARect.IsEmpty then Exit;
  if (Parent = nil) or not Parent.HandleAllocated then begin
    Invalidate;
    Exit;
  end;
  R := TRect.Intersect(ARect, ClientRect);
  if R.IsEmpty then Exit;
  if FBufferDirty.IsEmpty then FBufferDirty := R else FBufferDirty := TRect.Union(FBufferDirty, R);
  OffsetRect(R, Left, Top);
  LCLIntf.InvalidateRect(Parent.Handle, @R, False);
end;

procedure TCSSShape.SetHTML(AValue: TStrings);
begin
  FHTML.Assign(AValue);
end;

procedure TCSSShape.SetCSS(AValue: TStrings);
begin
  FCSS.Assign(AValue);
end;

procedure TCSSShape.SetBodyClass(const AValue: String);
begin
  if FBodyClass = AValue then Exit;
  FBodyClass := AValue;
  MarkupChanged(nil);
end;

procedure TCSSShape.MarkupChanged(Sender: TObject);
begin
  if not (csLoading in ComponentState) then RebuildMarkup;
end;

procedure TCSSShape.Loaded;
begin
  inherited Loaded;
  if (FHTML.Count > 0) or (FCSS.Count > 0) or (FBodyClass <> '') then RebuildMarkup;
end;

(*
  Content from HTML, CSS and BodyClass properties (content created in code is replaced)
*)
procedure TCSSShape.RebuildMarkup;
begin
  // markup from Object Inspector uses utility classes as in form designer (unless application set own resolver)
  if not Assigned(CSSUtilityResolver) then CSSTailwindEnable;
  if FCSS.Count > 0 then begin
    if FSheet = nil then FSheet := TCSSStyleSheet.Create(Self);
    FSheet.Style := FCSS.Text;
    Body.StyleSheet := FSheet;
  end;
  Body.SetHTML(FHTML.Text);
  Body.SetClass(FBodyClass);
  Body.ApplyStyles;
  Changed;
end;

procedure TCSSShape.SetInspect(AValue: Boolean);
begin
  if FInspect = AValue then Exit;
  FInspect := AValue;
  FInspectNode := nil;
  Invalidate;
end;

(*
  Debug overlay like in browser inspector: margin, border, padding and content box of node, guide lines
  and label with element, classes and size
*)
procedure TCSSShape.PaintInspector(ACanvas: TCanvas; ANode: THtmlNode);
const
  DASH = 4;
  GAP = 3;
var
  N: THtmlNode;
  MR, BR, PR, CR: TRect;
  S, Dims: String;
  I, X, Y, TW, TH, W1: Integer;
  Ratio: Single;
  // area between outer and inner rectangle filled with semi-transparent color
  procedure Frame(AOuter, AInner: TRect; R, G, B, A: Byte);
  var
    Bmp: TBitmap;
    procedure Part(AL, AT, AR, AB: Integer);
    begin
      if (AR > AL) and (AB > AT) then ACanvas.StretchDraw(Rect(AL, AT, AR, AB), Bmp);
    end;
  begin
    Bmp := CSSAlphaBitmap(R, G, B, A);
    AInner := TRect.Intersect(AInner, AOuter);
    if AInner.IsEmpty then begin
      Part(AOuter.Left, AOuter.Top, AOuter.Right, AOuter.Bottom);
      Exit;
    end;
    Part(AOuter.Left, AOuter.Top, AOuter.Right, AInner.Top);
    Part(AOuter.Left, AInner.Bottom, AOuter.Right, AOuter.Bottom);
    Part(AOuter.Left, AInner.Top, AInner.Left, AInner.Bottom);
    Part(AInner.Right, AInner.Top, AOuter.Right, AInner.Bottom);
  end;
  procedure HLine(AY: Integer);
  var
    K: Integer;
  begin
    K := 0;
    while K < ClientWidth do begin
      ACanvas.FillRect(K, AY, K + DASH, AY + 1);
      Inc(K, DASH + GAP);
    end;
  end;
  procedure VLine(AX: Integer);
  var
    K: Integer;
  begin
    K := 0;
    while K < ClientHeight do begin
      ACanvas.FillRect(AX, K, AX + 1, K + DASH);
      Inc(K, DASH + GAP);
    end;
  end;
  function Px(AValue: Integer): String;
  begin
    Result := FormatFloat('0.#', AValue / Ratio);
  end;
begin
  // node can be removed from tree since last mouse move
  N := FBodyNode;
  while Assigned(N) and (N <> ANode) do N := N.GetNext(N, True);
  if N = nil then begin
    FInspectNode := nil;
    Exit;
  end;
  Ratio := FBodyNode.PixelRatio;
  if Ratio <= 0 then Ratio := 1;
  ACanvas.ClipRect := ClientRect;
  with ANode.CompSize do begin
    MR := ANode.TransformedBounds(MarginRect);
    BR := ANode.TransformedBounds(ContentRect);
    PR := ANode.TransformedBounds(ANode.PaddingBox);
    CR := ANode.TransformedBounds(RealContentRect);
  end;
  Frame(MR, BR, 246, 178, 107, 110);     // margin
  Frame(BR, PR, 255, 229, 153, 140);     // border
  Frame(PR, CR, 147, 196, 125, 120);     // padding
  Frame(CR, Rect(0, 0, 0, 0), 111, 168, 220, 110);   // content
  // guide lines on border box edges
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := RGBToColor(59, 130, 246);
  HLine(BR.Top);
  HLine(BR.Bottom - 1);
  VLine(BR.Left);
  VLine(BR.Right - 1);
  // label: element#id.class  width x height
  S := ANode.Element;
  if ANode.Id <> '' then S := S + '#' + ANode.Id;
  for I := 0 to ANode.ClassList.Count - 1 do S := S + '.' + ANode.ClassList.Item[I];
  if UTF8Length(S) > 60 then S := UTF8Copy(S, 1, 58) + '...';
  Dims := Px(BR.Width) + ' x ' + Px(BR.Height);
  ACanvas.Font.Name := 'default';
  ACanvas.Font.Height := -12;
  ACanvas.Font.Style := [];
  W1 := ACanvas.TextWidth(S);
  TW := W1 + ACanvas.TextWidth('  ' + Dims) + 12;
  TH := ACanvas.TextHeight('Wg') + 6;
  X := Max(0, Min(BR.Left, ClientWidth - TW));
  Y := BR.Top - TH - 4;
  if Y < 0 then Y := BR.Bottom + 4;
  if Y + TH > ClientHeight then Y := Max(0, BR.Top + 4);
  ACanvas.Brush.Color := RGBToColor(36, 41, 51);
  ACanvas.FillRect(X, Y, X + TW, Y + TH);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Color := RGBToColor(216, 160, 255);
  ACanvas.TextOut(X + 6, Y + 3, S);
  ACanvas.Font.Color := RGBToColor(220, 224, 230);
  ACanvas.TextOut(X + 6 + W1, Y + 3, '  ' + Dims);
  ACanvas.Brush.Style := bsSolid;
end;

(*
  Click on node without OnClick focuses LCL control inside it (like click on <label> in HTML): nearest parent
  which contains exactly one focusable aligned control, eg. wrapper of input with icons, or field with label.
*)
function TCSSShape.FocusControlOf(ANode: THtmlNode): Boolean;
var
  Found: TWinControl;
  Count: Integer;
  procedure Collect(AParent: THtmlNode);
  var
    C: THtmlNode;
  begin
    if not AParent.Visible then Exit;
    if (AParent.AlignControl is TWinControl) and TWinControl(AParent.AlignControl).CanFocus then begin
      Inc(Count);
      Found := TWinControl(AParent.AlignControl);
    end;
    C := AParent.FirstChild;
    while Assigned(C) and (Count < 2) do begin
      Collect(C);
      C := AParent.GetNext(C);
    end;
  end;
begin
  Result := False;
  while Assigned(ANode) and (ANode <> FBodyNode) and not Assigned(ANode.OnClick) do begin
    Count := 0;
    Collect(ANode);
    if Count = 1 then begin
      Found.SetFocus;
      Exit(True);
    end;
    if Count > 1 then Exit;
    ANode := ANode.ParentNode;
  end;
end;

procedure TCSSShape.SetParent(NewParent: TWinControl);
begin
  inherited SetParent(NewParent);
  if Assigned(NewParent) then begin
    InvalidatePreferredSize;
    AdjustSize;
  end;
end;

(*
  Set :active state for visible nodes at position (AActive = False clears all)
*)
(*
  Node is the top node at mouse position or its parent (only these get :hover and :active, as in browser)
*)
function InMouseChain(ANode, ATop: THtmlNode): Boolean;
begin
  while Assigned(ATop) do begin
    if ATop = ANode then Exit(True);
    ATop := ATop.ParentNode;
  end;
  Result := False;
end;

procedure TCSSShape.SetActiveNodes(X, Y: Integer; AActive: Boolean);
var
  Node, Top: THtmlNode;
  NewActive: Boolean;
  ChangedNodes: TList;
begin
  ChangedNodes := TList.Create;
  try
    Top := nil;
    if AActive then Top := FBodyNode.NodeAtPosition(Point(X, Y), False);
    Node := FBodyNode;
    while Assigned(Node) do begin
      NewActive := AActive and InMouseChain(Node, Top);
      if Node.Active <> NewActive then begin
        Node.Active := NewActive;
        ChangedNodes.Add(Node);
      end;
      Node := Node.GetNext(Node, True);
    end;
    RestyleNodes(ChangedNodes);
  finally
    ChangedNodes.Free;
  end;
end;

(*
  Scroll deepest scrollable node at position (or its parent when it is at the end)
*)
(*
  Deepest scrollable node at position which can scroll by DX, DY (or its parent when it is at the end).
  Vertical wheel scrolls horizontally in node which scrolls only horizontally (eg. tabs).
*)
function TCSSShape.ScrollNodeAt(const APos: TPoint; var DX, DY: Integer): THtmlNode;
var
  List: TList;
  I: Integer;
  N: THtmlNode;
  procedure Collect(ANode: THtmlNode);
  var
    Children: THtmlNodeArray;
    K: Integer;
  begin
    if not ANode.Visible then Exit;
    if ANode.ClipsContent and ANode.HitTest(APos) then List.Add(ANode);
    Children := ANode.PaintOrder;
    for K := 0 to High(Children) do Collect(Children[K]);
  end;
begin
  Result := nil;
  List := TList.Create;
  try
    Collect(FBodyNode);
    for I := List.Count - 1 downto 0 do begin
      N := THtmlNode(List[I]);
      if N.CanScroll(DX, DY) then Exit(N);
      if (DX = 0) and (N.ScrollMax.Y = N.ScrollMin.Y) and N.CanScroll(DY, 0) then begin
        DX := DY;
        DY := 0;
        Exit(N);
      end;
    end;
  finally
    List.Free;
  end;
end;

function TCSSShape.ScrollAt(const APos: TPoint; DX, DY: Integer; ASmooth: Boolean): Boolean;
var
  N: THtmlNode;
  P: TPoint;
begin
  Result := False;
  N := ScrollNodeAt(APos, DX, DY);
  if N = nil then Exit;
  if ASmooth then begin
    // smooth scroll (as in browser): next wheel step continues from target
    if N = FSmoothNode then P := FSmoothTo else P := Point(N.ScrollX, N.ScrollY);
    FSmoothTo := Point(EnsureRange(P.X + DX, N.ScrollMin.X, N.ScrollMax.X), EnsureRange(P.Y + DY, N.ScrollMin.Y, N.ScrollMax.Y));
    FSmoothFrom := Point(N.ScrollX, N.ScrollY);
    FSmoothStart := GetTickCount64;
    FSmoothNode := N;
    FAnimTimer.Interval := 15;
    FAnimTimer.Enabled := True;
    Exit(True);
  end;
  if N = FSmoothNode then FSmoothNode := nil;
  Result := N.ScrollBy(DX, DY);
  if Result then ScrollChanged(N);
end;

(*
  Next step of smooth scroll, False when it is finished
*)
function TCSSShape.TickSmoothScroll: Boolean;
const
  DURATION = 160;
var
  N: THtmlNode;
  T: Single;
begin
  Result := False;
  if FSmoothNode = nil then Exit;
  N := FBodyNode;      // node can be removed from tree
  while Assigned(N) and (N <> FSmoothNode) do N := N.GetNext(N, True);
  if N = nil then begin
    FSmoothNode := nil;
    Exit;
  end;
  T := Min(1, (GetTickCount64 - FSmoothStart) / DURATION);
  T := 1 - (1 - T) * (1 - T) * (1 - T);        // ease-out
  N.SetScroll(FSmoothFrom.X + Round((FSmoothTo.X - FSmoothFrom.X) * T), FSmoothFrom.Y + Round((FSmoothTo.Y - FSmoothFrom.Y) * T));
  ScrollChanged(N);
  if T >= 1 then FSmoothNode := nil else Result := True;
end;

(*
  Mouse wheel: steps of wheel (multiples of 120) are scrolled smoothly by 48 px, touchpads with precise
  deltas scroll directly (macOS sends pixels * 8 vertically, pixels * 120 horizontally)
*)
function TCSSShape.WheelScroll(const APos: TPoint; WheelDelta: Integer; AHorz: Boolean): Boolean;
var
  D: Integer;
  Notch: Boolean;
begin
  Notch := (WheelDelta mod 120 = 0) and (GetTickCount64 - FLastWheel > 50);
  FLastWheel := GetTickCount64;
  D := Round(WheelDelta * 0.4);     // 120 = 48 px
  {$ifdef darwin}
  if not Notch then
    if AHorz then D := Round(WheelDelta / 120) else D := Round(WheelDelta / 8);
  {$endif}
  if D = 0 then D := Sign(WheelDelta);
  if AHorz then Result := ScrollAt(APos, D, 0, Notch)
    else Result := ScrollAt(APos, 0, -D, Notch);
end;

(*
  Scroll position was changed: only repaint and move aligned controls (layout is not changed)
*)
procedure TCSSShape.ScrollChanged(ANode: THtmlNode);
var
  P: TPoint;
begin
  Body.AlignControlsTo(Left, Top);
  P := ScreenToControl(Mouse.CursorPos);
  if PtInRect(ClientRect, P) and (FDragNode = nil) then MouseMove([], P.X, P.Y);   // hover of content under mouse
  if (ANode = nil) or (ANode = Body) then Invalidate else InvalidateArea(ANode.PaintedRect);   // only scrolled node
end;

function TCSSShape.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Result then Exit;
  if ssShift in Shift then Result := WheelScroll(ScreenToControl(Mouse.CursorPos), -WheelDelta, True)
    else Result := WheelScroll(ScreenToControl(Mouse.CursorPos), WheelDelta, False);
end;

function TCSSShape.DoMouseWheelHorz(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheelHorz(Shift, WheelDelta, MousePos);
  if Result then Exit;
  Result := WheelScroll(ScreenToControl(Mouse.CursorPos), WheelDelta, True);
end;

(*
  Mouse wheel over LCL control in node (TEdit ...) scrolls content of shape. Controls which scroll
  themselves (memo, list) keep the wheel.
*)
procedure TCSSShape.ControlMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if Handled or (Sender is TCustomMemo) or (Sender is TCustomListBox) or (Sender is TCustomComboBox) or
    (Sender is TScrollingWinControl) then Exit;
  if ssShift in Shift then Handled := WheelScroll(ScreenToControl(Mouse.CursorPos), -WheelDelta, True)
    else Handled := WheelScroll(ScreenToControl(Mouse.CursorPos), WheelDelta, False);
end;

procedure TCSSShape.HookControlWheels;
var
  N: THtmlNode;
begin
  if csDesigning in ComponentState then Exit;
  N := FBodyNode;
  while Assigned(N) do begin
    if Assigned(N.AlignControl) and (FWheelControls.IndexOf(N.AlignControl) < 0) then begin
      FWheelControls.Add(N.AlignControl);
      N.AlignControl.AddHandlerOnMouseWheel(ControlMouseWheel);
      N.AlignControl.FreeNotification(Self);
    end;
    N := N.GetNext(N, True);
  end;
end;

procedure TCSSShape.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and Assigned(FWheelControls) then FWheelControls.Remove(AComponent);
end;

(*
  :focus and :focus-within for nodes with aligned LCL controls
*)
procedure TCSSShape.ActiveControlChanged(Sender: TObject; LastControl: TControl);
var
  Node, P: THtmlNode;
  Active: TControl;
  F: Boolean;
  ChangedNodes: TList;
begin
  if csDestroying in ComponentState then Exit;
  Active := Screen.ActiveControl;
  ChangedNodes := TList.Create;
  try
    Node := FBodyNode;
    while Assigned(Node) do begin
      F := Assigned(Node.AlignControl) and Assigned(Active) and ((Node.AlignControl = Active) or
        ((Node.AlignControl is TWinControl) and TWinControl(Node.AlignControl).ContainsControl(Active)));
      if Node.Focused <> F then begin
        Node.Focused := F;
        P := Node;                          // node and its parents (focus-within) are styled again
        while Assigned(P) do begin
          if ChangedNodes.IndexOf(P) < 0 then ChangedNodes.Add(P);
          P := P.ParentNode;
        end;
      end;
      Node := Node.GetNext(Node, True);
    end;
    RestyleNodes(ChangedNodes);             // only area of nodes which look different is painted again
  finally
    ChangedNodes.Free;
  end;
end;

procedure TCSSShape.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  Node: THtmlNode;
begin
  inherited MouseDown(Button, Shift, X, Y);
  // dragging of scrollbar thumb
  if Button = mbLeft then begin
    Node := FBodyNode;
    while Assigned(Node) do begin
      if Node.Visible and (Node.ThumbAt(Point(X, Y)) > 0) then begin
        FDragNode := Node;
        FDragAxis := Node.ThumbAt(Point(X, Y));
        if FDragAxis = 1 then begin FDragStart := Y; FDragScroll := Node.ScrollY; end
          else begin FDragStart := X; FDragScroll := Node.ScrollX; end;
        Exit;
      end;
      Node := Node.GetNext(Node, True);
    end;
  end;
  FMouseDownNode := FBodyNode.NodeAtPosition( Point(X, Y));
  if Button = mbLeft then begin
    if FMouseDownNode = nil then FocusControlOf(FBodyNode.NodeAtPosition(Point(X, Y), False));
    SetActiveNodes(X, Y, True);
  end;
end;

procedure TCSSShape.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  Node: THtmlNode;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Assigned(FDragNode) then begin
    FDragNode := nil;
    Exit;
  end;
  if Button = mbLeft then SetActiveNodes(X, Y, False);
  if Assigned(FMouseDownNode) then begin
    Node := FMouseDownNode;
    FMouseDownNode := Nil;
    if Node = FBodyNode.NodeAtPosition( Point(X, Y)) then begin
      if Assigned(Node.OnClick) then Node.OnClick(Node);   // note: OnClick can change or free nodes
    end;
  end;
end;

procedure TCSSShape.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Node, Top: THtmlNode;
  Modified: Boolean;
  NewCursor: TCursor;
  ChangedNodes: TList;
begin
  inherited MouseMove(Shift, X, Y);
  if FInspect then begin
    Node := FBodyNode.NodeAtPosition(Point(X, Y), False);
    if Node <> FInspectNode then begin
      FInspectNode := Node;
      Invalidate;
      if Assigned(FOnInspect) then FOnInspect(Self, Node);
    end;
  end;
  if Assigned(FDragNode) then begin
    if FDragAxis = 1 then Modified := FDragNode.ScrollByThumb(1, FDragScroll, Y - FDragStart)
      else Modified := FDragNode.ScrollByThumb(2, FDragScroll, X - FDragStart);
    if Modified then ScrollChanged(FDragNode);
    Exit;
  end;
  // only the top node under mouse and its parents are hovered (not nodes covered by a dialog or popup)
  if FHoverEnabled then Top := FBodyNode.NodeAtPosition(Point(X, Y), False) else Top := nil;
  NewCursor := crNone;
  Node := Top;
  while Assigned(Node) and (NewCursor = crNone) do begin    // cursor of nearest node which sets it
    if Node.CompStyle.Cursor <> crDefault then NewCursor := Node.CompStyle.Cursor;
    Node := Node.ParentNode;
  end;
  Node :=  GetBodyNode;
  ChangedNodes := TList.Create;
  try
    while Assigned(Node) do begin
      if InMouseChain(Node, Top) then begin
        if not Node.Hovered then begin
          Node.Hovered := True;
          ChangedNodes.Add(Node);
        end;
      end else begin
        if (Node.Hovered) then begin    // remove hovered styles
          Node.Hovered := False;
          ChangedNodes.Add(Node);
        end;
      end;
      Node := Node.GetNext(Node, True);
    end;
    if NewCursor <> crNone then Self.Cursor := NewCursor else Self.Cursor := crDefault;
    RestyleNodes(ChangedNodes);
  finally
    ChangedNodes.Free;
  end;
end;

(*
  Styles of nodes with changed state (hover, active, focus) are applied again. Layout is computed only
  when sizes are changed, otherwise only changed area is repainted (fast also with thousands of nodes).
*)
procedure TCSSShape.RestyleNodes(ANodes: TList);
var
  I: Integer;
  N: THtmlNode;
  Dirty: TRect;
  NeedLayout, StateRules: Boolean;
begin
  if ANodes.Count = 0 then Exit;
  // descendants depend on state of node: group-hover, or stylesheet rules with state of ancestor
  StateRules := Assigned(Body.StyleSheet) and ((Pos(':hover', Body.StyleSheet.Style) > 0) or
    (Pos(':active', Body.StyleSheet.Style) > 0) or (Pos(':focus', Body.StyleSheet.Style) > 0));
  NeedLayout := False;
  Dirty := Rect(0, 0, 0, 0);
  for I := 0 to ANodes.Count - 1 do begin
    N := THtmlNode(ANodes[I]);
    if N.RestyleState(StateRules or N.ClassList.Contains('group'), Dirty) then begin
      NeedLayout := True;
      if N <> Body then Body.NoteChanged(N);    // its area is painted again after layout
    end;
  end;
  if NeedLayout or FInspect then begin
    InvalidateArea(Dirty);
    Changed;
  end else
    InvalidateArea(Dirty);
  StartAnimations;
end;

procedure TCSSShape.MouseLeave;
begin
  inherited MouseLeave;
  MouseMove([], -1, -1);
end;

procedure TCSSShape.MouseEnter;
var
  pt: TPoint;
begin
  inherited MouseEnter;
  pt := ScreenToControl(Mouse.CursorPos);
  MouseMove([], pt.x, pt.y);
end;

(*
  Calculate size based on autosize settings.
*)

procedure TCSSShape.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: Integer; WithThemeSpace: Boolean);
var
  AWidth, AHeight: Integer;
begin
  // preferred size is used by LCL only for AutoSize: no layout for other shapes (it would replace current layout)
  if (Parent = nil) or (not Parent.HandleAllocated) or not AutoSize then Exit;
  if WidthIsAnchored then AWidth := Width else AWidth := -1;
  if (HeightIsAnchored and AutoSize) then AHeight := Height else AHeight := -1;
  UpdatePixelRatio;
  FBodyNode.LayoutTo( 0, 0, AWidth, AHeight);
  FLayoutValid := False;     // body layout is for preferred size now
  if WidthIsAnchored then PreferredWidth := 0 else PreferredWidth := FBodyNode.CompSize.MarginRect.Width;
  if (HeightIsAnchored and AutoSize) then PreferredHeight := 0 else PreferredHeight := FBodyNode.CompSize.MarginRect.Height;
end;

constructor TCSSShape.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBodyNode := THtmlNode.Create;
  FBodyNode.Id := 'body';
  FBodyNode.ParentControl := Self;
  FIsChanged := True;
  FScaleByDPI := True;
  FHoverEnabled := True;
  FBuffered := True;
  if CSSShapes = nil then CSSShapes := TList.Create;
  CSSShapes.Add(Self);
  FHTML := TStringList.Create;
  TStringList(FHTML).OnChange := MarkupChanged;
  FCSS := TStringList.Create;
  TStringList(FCSS).OnChange := MarkupChanged;
  FWheelControls := TList.Create;
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Enabled := False;
  FAnimTimer.Interval := 15;
  FAnimTimer.OnTimer := AnimTimer;
  if not (csDesigning in ComponentState) then Screen.AddHandlerActiveControlChanged(ActiveControlChanged);
  SetBounds(0,0, 150, 150);  // default size
end;

destructor TCSSShape.Destroy;
var
  I: Integer;
begin
  if Assigned(CSSShapes) then CSSShapes.Remove(Self);
  CSSUpdateForget(Self);
  for I := 0 to FWheelControls.Count - 1 do begin
    TControl(FWheelControls[I]).RemoveHandlerOnMouseWheel(ControlMouseWheel);
    TControl(FWheelControls[I]).RemoveFreeNotification(Self);
  end;
  FreeAndNil(FWheelControls);
  FreeAndNil(FBuffer);
  FreeAndNil(FHTML);
  FreeAndNil(FCSS);
  Screen.RemoveHandlerActiveControlChanged(ActiveControlChanged);
  FBodyNode.Free;
  inherited Destroy;
end;

(*
  Layout and repaint after changes of nodes. Only area of changed, removed and moved nodes is painted again when
  changes are known (nodes reported them), otherwise whole shape (eg. application changed stylesheet).
*)
procedure TCSSShape.Changed;
var
  OldRects: TCSSRectArray;
  Precise: Boolean;
begin
  if CSSUpdatePending(Self) then Exit;      // CSSBeginUpdate: laid out once in CSSEndUpdate
  Precise := FLayoutValid and Body.HasChanges and not Body.ChangedAll and Assigned(Parent) and Parent.HandleAllocated;
  OldRects := nil;
  if Precise then OldRects := Body.PaintedRects;
  FIsChanged := True;
  Relayout(Width, Height);
  InvalidatePreferredSize;
  AdjustSize;
  if Precise then
    InvalidateArea(Body.TakeDirtyRect(OldRects))
  else begin
    Body.TakeDirtyRect(nil);
    Invalidate;
  end;
  StartAnimations;
end;

procedure TCSSShape.Invalidate;
begin
  FBufferDirty := ClientRect;
  inherited Invalidate;
end;

(*
  Changed area is painted into a bitmap of its size and copied into buffer, so nothing is painted outside of it
  (Cocoa doesn't clip text in bitmaps). Whole buffer is painted directly.
*)
procedure TCSSShape.PaintToBuffer(const ARect: TRect);
var
  Part: TBitmap;
begin
  if (ARect.Width = Width) and (ARect.Height = Height) then begin
    Body.PaintTo(FBuffer.Canvas, ARect);
    FBuffer.Canvas.Clipping := False;      // painting leaves clip rect of last node
    Exit;
  end;
  Part := TBitmap.Create;
  try
    Part.PixelFormat := pf24bit;
    Part.SetSize(ARect.Width, ARect.Height);
    SetWindowOrgEx(Part.Canvas.Handle, ARect.Left, ARect.Top, nil);
    Body.PaintTo(Part.Canvas, ARect);
    SetWindowOrgEx(Part.Canvas.Handle, 0, 0, nil);
    Part.Canvas.Clipping := False;
    FBuffer.Canvas.Clipping := False;
    FBuffer.Canvas.CopyRect(ARect, Part.Canvas, Rect(0, 0, ARect.Width, ARect.Height));
  finally
    Part.Free;
  end;
end;

function TCSSShape.UseBuffer: Boolean;
begin
  Result := FBuffered and not (csDesigning in ComponentState) and (Body.PaintScale <= 1) and
    (Body.CompStyle.Background.Color.ColorType = cctNormal) and (Body.CompStyle.Background.Color.Alpha = 255) and
    (Body.CompStyle.Background.Image = '');
end;

procedure TCSSShape.ChangeBounds(ALeft, ATop, AWidth, AHeight: integer;
  KeepBase: boolean);
begin
  if (AWidth <> Width) or (AHeight <> Height) then FBufferDirty := Rect(0, 0, Max(AWidth, 0), Max(AHeight, 0));   // painted directly while resized
  inherited ChangeBounds(ALeft, ATop, AWidth, AHeight, KeepBase);
//  if AutoSize then AWidth :=  -1;
  Relayout(AWidth, AHeight);
end;

function TCSSShape.NodeMarginToScreen(ANode: THtmlNode): TRect;
var
  P: TPoint;
begin
  P := ClientToScreen(Point(ANode.CompSize.MarginRect.Left, ANode.CompSize.MarginRect.Top));
  Result := Rect(P.x, P.y, P.x + ANode.CompSize.MarginRect.Width, P.y + ANode.CompSize.MarginRect.Height);
end;

function TCSSShape.NodeMarginToClient(ANode: THtmlNode): TRect;
var
  P: TPoint;
begin
  P := ClientToParent(Point(ANode.CompSize.MarginRect.Left, ANode.CompSize.MarginRect.Top), TWinControl(Self.GetTopParent));
  Result := Rect(P.x, P.y, P.x + ANode.CompSize.MarginRect.Width, P.y + ANode.CompSize.MarginRect.Height);
end;

(*
  Set FontAwesome (4.x) font file for THTMLFaNode, default is fontawesome-webfont.ttf in application folder
*)
procedure SetFontAwesomeFile(const AFileName: String);
begin
  if FileExists(AFileName) then FAFont.Name := AFileName;
end;

initialization
begin
	FAFont := TFreeTypeFont.Create;
  SetFontAwesomeFile(Application.Location + 'fontawesome-webfont.ttf');
end;

finalization
begin
	FAFont.Free;
  FreeAndNil(CSSShapes);
end;

end.

