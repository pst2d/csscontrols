unit CSSCtrls;

{$ifdef fpc}
  {$mode delphi}{$H+}
{$endif}

interface
uses
  Classes, SysUtils,  Types, Math,
  strutils,
  {$ifdef fpc}
  Controls,  Graphics, Forms, ExtCtrls,
  LMessages,LCLIntf, LazUTF8,
  FPimage, LCLType, LCLProc, IntfGraphics, GraphType, EasyLazFreeType, LazFreeTypeIntfDrawer,      // font rendering
  {$endif}
  cssbase;

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
    FAnimTimer: TTimer;             // runs only while some nodes are animated
    FInspect: Boolean;              // debug overlay of node under mouse (like browser inspector)
    FInspectNode: THtmlNode;
    FOnInspect: TCSSNodeEvent;
    procedure SetInspect(AValue: Boolean);
    procedure AnimTimer(Sender: TObject);
    procedure InvalidateArea(const ARect: TRect);
    function FocusControlOf(ANode: THtmlNode): Boolean;
    function GetBodyNode: THtmlNode;
    function ScrollAt(const APos: TPoint; DX, DY: Integer): Boolean;
    procedure ScrollChanged;
    procedure ActiveControlChanged(Sender: TObject; LastControl: TControl);
    function GetStyle: String;
    procedure SetScaleByDPI(AValue: Boolean);
    procedure SetStyle(AValue: String);
    procedure Relayout(AWidth, AHeight: Integer);
    procedure UpdatePixelRatio;
    procedure UpdateViewport(AWidth: Integer);
    procedure SetActiveNodes(X, Y: Integer; AActive: Boolean);
  protected
    procedure CalculatePreferredSize(var PreferredWidth,
      PreferredHeight: Integer; WithThemeSpace: Boolean); override;
    procedure Paint; override;
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

  published
    property Align;
    property AutoSize;
    property Anchors;
    property Body: THtmlNode read GetBodyNode;
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
  procedure Register;

implementation
{$R csspckg_lazarus.res}

var
  FAFont: TFreeTypeFont;


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
begin
  if (FCachedWidth <> AWidth) or (FCachedHeight <> AHeight) or FIsChanged or not FLayoutValid then begin
    UpdatePixelRatio;
    UpdateViewport(AWidth);
    Body.LayoutTo(0, 0, AWidth, AHeight);
    Body.AlignControlsTo(Left, Top);
    FLayoutValid := True;
  end;
  FCachedWidth := AWidth;
  FCachedHeight := AHeight;
  FIsChanged := False;
end;

procedure TCSSShape.Paint;
var
  R: TRect;
begin
  if Assigned(Parent) then Body.PaintScale := Parent.GetCanvasScaleFactor;   // 2 on macOS Retina
  if not FLayoutValid then begin     // layout was changed by CalculatePreferredSize
    Body.LayoutTo(0, 0, Width, Height);
    FLayoutValid := True;
  end;
  // only invalidated area is painted (nodes outside of it are skipped)
  R := TRect.Intersect(Canvas.ClipRect, ClientRect);
  if R.IsEmpty then R := ClientRect;
  Body.PaintTo(Self.Canvas, R);
  if FInspect and Assigned(FInspectNode) then PaintInspector(Canvas, FInspectNode);
  if Assigned(FOnPaint) then FOnPaint(Self);
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
begin
  Before := Body.AnimationRects;
  if not Body.AnimationTick(GetTickCount64) then begin
    FAnimTimer.Enabled := False;
    Exit;
  end;
  if FInspect then begin
    Invalidate;
    Exit;
  end;
  // transitions are smooth (60 fps), endless built-in animations (spinner ...) use 30 fps to save CPU
  if Body.AnimatingTransitions then FAnimTimer.Interval := 15 else FAnimTimer.Interval := 33;
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
  OffsetRect(R, Left, Top);
  LCLIntf.InvalidateRect(Parent.Handle, @R, False);
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
procedure TCSSShape.SetActiveNodes(X, Y: Integer; AActive: Boolean);
var
  Node: THtmlNode;
  NewActive, Modified: Boolean;
begin
  Modified := False;
  Node := FBodyNode;
  while Assigned(Node) do begin
    NewActive := AActive and Node.Visible and Node.HitTest(Point(X, Y));
    if Node.Active <> NewActive then begin
      Node.Active := NewActive;
      Modified := True;
    end;
    Node := Node.GetNext(Node, True);
  end;
  if Modified then begin
    Body.ApplyStyles;
    Changed;
  end;
end;

(*
  Scroll deepest scrollable node at position (or its parent when it is at the end)
*)
function TCSSShape.ScrollAt(const APos: TPoint; DX, DY: Integer): Boolean;
var
  List: TList;
  I: Integer;
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
  Result := False;
  List := TList.Create;
  try
    Collect(FBodyNode);
    for I := List.Count - 1 downto 0 do
      if THtmlNode(List[I]).CanScroll(DX, DY) then begin
        Result := THtmlNode(List[I]).ScrollBy(DX, DY);
        Break;
      end;
  finally
    List.Free;
  end;
  if Result then ScrollChanged;
end;

(*
  Scroll position was changed: only repaint and move aligned controls (layout is not changed)
*)
procedure TCSSShape.ScrollChanged;
var
  P: TPoint;
begin
  Body.AlignControlsTo(Left, Top);
  P := ScreenToControl(Mouse.CursorPos);
  if PtInRect(ClientRect, P) and (FDragNode = nil) then MouseMove([], P.X, P.Y);   // hover of content under mouse
  Invalidate;
end;

function TCSSShape.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  P: TPoint;
  D: Integer;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Result then Exit;
  P := ScreenToControl(Mouse.CursorPos);
  D := -Round(WheelDelta * 0.4);    // 120 = 48 px
  if D = 0 then D := -Sign(WheelDelta);
  if ssShift in Shift then Result := ScrollAt(P, D, 0) else Result := ScrollAt(P, 0, D);
end;

function TCSSShape.DoMouseWheelHorz(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  D: Integer;
begin
  Result := inherited DoMouseWheelHorz(Shift, WheelDelta, MousePos);
  if Result then Exit;
  D := Round(WheelDelta * 0.4);
  if D = 0 then D := Sign(WheelDelta);
  Result := ScrollAt(ScreenToControl(Mouse.CursorPos), D, 0);
end;

(*
  :focus and :focus-within for nodes with aligned LCL controls
*)
procedure TCSSShape.ActiveControlChanged(Sender: TObject; LastControl: TControl);
var
  Node: THtmlNode;
  Active: TControl;
  F, Modified: Boolean;
begin
  if csDestroying in ComponentState then Exit;
  Active := Screen.ActiveControl;
  Modified := False;
  Node := FBodyNode;
  while Assigned(Node) do begin
    F := Assigned(Node.AlignControl) and Assigned(Active) and ((Node.AlignControl = Active) or
      ((Node.AlignControl is TWinControl) and TWinControl(Node.AlignControl).ContainsControl(Active)));
    if Node.Focused <> F then begin
      Node.Focused := F;
      Modified := True;
    end;
    Node := Node.GetNext(Node, True);
  end;
  if Modified then begin
    Body.ApplyStyles;
    Changed;
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
// TODO: move this part into Node handling to provide support for various controls
var
  Node: THtmlNode;
  Modified: Boolean;
  NewCursor: TCursor;
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
    if Modified then ScrollChanged;
    Exit;
  end;
  Node :=  GetBodyNode;
  Modified := False;
  NewCursor :=  crNone;
  while Assigned(Node) do begin
    if Node.Visible and Node.HitTest(Point(X, Y)) then begin
      if Node.CompStyle.Cursor <> crDefault then NewCursor := Node.CompStyle.Cursor;
      if not Node.Hovered then begin
        Node.Hovered := True;
        Modified := True;
      end;
    end else begin
      if (Node.Hovered) then begin    // remove hovered styles -> rebuild styles
        Node.Hovered := False;
        Modified := True;
      end;
    end;
    Node := Node.GetNext(Node, True);
  end;
  if NewCursor <> crNone then Self.Cursor := NewCursor else Self.Cursor := crDefault;
  if Modified then begin
    Body.ApplyStyles;
    Changed;
  end;
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
  if (Parent = nil) or (not Parent.HandleAllocated) then Exit;
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
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Enabled := False;
  FAnimTimer.Interval := 15;
  FAnimTimer.OnTimer := AnimTimer;
  if not (csDesigning in ComponentState) then Screen.AddHandlerActiveControlChanged(ActiveControlChanged);
  SetBounds(0,0, 150, 150);  // default size
end;

destructor TCSSShape.Destroy;
begin
  Screen.RemoveHandlerActiveControlChanged(ActiveControlChanged);
  FBodyNode.Free;
  inherited Destroy;
end;

procedure TCSSShape.Changed;
begin
  FIsChanged := True;
  Relayout(Width, Height);

  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TCSSShape.ChangeBounds(ALeft, ATop, AWidth, AHeight: integer;
  KeepBase: boolean);
begin
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
end;

end.

