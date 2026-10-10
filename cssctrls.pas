unit CSSCtrls;

{$ifdef fpc}
  {$mode delphi}{$H+}
{$endif}

interface
uses
  Classes, SysUtils,  Types,
  strutils,
  {$ifdef fpc}
  Controls,  Graphics, Forms,
  LMessages,LCLIntf,
  FPimage, LCLType, LCLProc, IntfGraphics, GraphType, EasyLazFreeType, LazFreeTypeIntfDrawer,      // font rendering
  {$endif}
  cssbase;

type

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
    function GetBodyNode: THtmlNode;
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
    procedure SetParent(NewParent: TWinControl); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer
      ); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
      override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseEnter; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Changed;
    procedure ChangeBounds(ALeft, ATop, AWidth, AHeight: integer;
      KeepBase: boolean); override;
    function NodeMarginToScreen(ANode: THtmlNode): TRect;
    function NodeMarginToClient(ANode: THtmlNode): TRect;

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
begin
  if Assigned(Parent) then Body.PaintScale := Parent.GetCanvasScaleFactor;   // 2 on macOS Retina
  if not FLayoutValid then begin     // layout was changed by CalculatePreferredSize
    Body.LayoutTo(0, 0, Width, Height);
    FLayoutValid := True;
  end;
  Body.PaintTo(Self.Canvas);
  if Assigned(FOnPaint) then FOnPaint(Self);
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

procedure TCSSShape.MouseDown(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  FMouseDownNode := FBodyNode.NodeAtPosition( Point(X, Y));
  if Button = mbLeft then SetActiveNodes(X, Y, True);
end;

procedure TCSSShape.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  Node: THtmlNode;
begin
  inherited MouseUp(Button, Shift, X, Y);
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
  SetBounds(0,0, 150, 150);  // default size
end;

destructor TCSSShape.Destroy;
begin
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

